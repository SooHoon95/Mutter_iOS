import Foundation

import AppFoundation
import Domain
import UIComponent
import AudioSync

/// 수신/열람 플로우. 딥링크 토큰 또는 내 편지 id로 편지를 불러오고,
/// 암호 게이트·예약공개 게이트·읽음확인 기록·오디오 재생을 조율한다.
@MainActor
@Observable
final class ViewerModelData {
  /// 화면 상태.
  enum ViewState {
    case loading
    case passwordRequired        // 암호 필요(틀렸거나 미입력)
    case revealPending(Date)     // 예약공개 전 — 이 시각에 열림
    case loginRequired(LetterCover)          // 로그인해야 열리는 편지 — 봉투 화면
    case letterLocked(LetterCover, Date)     // 무료 기간 종료 — 잠김 화면(시각 = 삭제 예정)
    case ready(LetterPayload, LetterTheme)
    case failed(String)
  }

  /// 데이터 출처.
  enum Source {
    case token(String)           // 딥링크 수신(/l/:token)
    case myLetter(String)        // 내 편지 미리보기(letterId)
  }

  var state: ViewState = .loading
  var password = ""
  /// 게이트(열기 ▶) 통과 여부.
  var isOpened = false
  /// 받은함 저장 완료 여부(중복 탭 방지 + "저장됨" 표시).
  /// 서버가 열람 시 자동 저장(0022) — 성공 로드 후 클라이언트가 true로 설정해 "저장됨" 표시.
  var savedToInbox = false
  /// 사진 서명 URL(Storage 경로 → URL). 본문을 받은 직후 한 번 채운다. 비어 있으면 사진 자리는 플레이스홀더.
  private(set) var photoURLs: [String: URL] = [:]
  /// 토큰 수신(로그인)에서 받는 권한·잔액. nil이면(비로그인·조회 실패) 간직 버튼을 숨긴다.
  private(set) var entitlements: Entitlements?
  /// 편지권 사용 중(중복 탭 방지).
  var isKeeping = false
  /// 이 화면에서 편지권으로 간직했는지 — 편지 끝 안내가 "간직한 편지예요"로 바뀐다.
  private(set) var isKept = false
  /// 간직하기 실패 문구(잠김 화면·편지 끝 공통).
  var keepErrorMessage: String?

  let player: LetterAudioPlayer

  private let source: Source
  private let deliveryUsecase: DeliveryUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterUsecase: LetterUsecasable
  /// nil이면 미인증(능력 부재 = nil, Mercury DI 패턴).
  private let inboxUsecase: InboxUsecasable?
  private let letterAccessUsecase: LetterAccessUsecasable
  /// nil이면 미인증 — 편지권을 쓸 수 없다.
  private let ticketUsecase: TicketUsecasable?
  /// 마지막으로 연 암호(잠긴 편지를 간직할 때 같은 암호로 다시 보낸다).
  @ObservationIgnored private var lastPassword: String?

  init(
    source: Source,
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    inboxUsecase: InboxUsecasable?,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable?,
    audioUsecase: AudioUsecasable
  ) {
    self.source = source
    self.deliveryUsecase = deliveryUsecase
    self.receiptUsecase = receiptUsecase
    self.letterUsecase = letterUsecase
    self.inboxUsecase = inboxUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
    self.player = LetterAudioPlayer(audioUsecase: audioUsecase)
  }

  /// "저장됨" 표시 노출 여부 — 토큰 수신 + 인증된 사용자(inboxUsecase != nil)일 때만.
  /// 서버가 get_letter_by_token 사이드 이펙트로 자동 저장(마이그레이션 0022)하므로 버튼 불필요.
  var canSaveToInbox: Bool {
    guard inboxUsecase != nil else { return false }
    if case .token = source { return true }
    return false
  }

  func load() async {
    switch source {
    case .token(let token):
      await loadByToken(token, password: nil)
    case .myLetter(let id):
      await loadMyLetter(id)
    }
  }

  /// 암호 입력 후 재시도.
  func submitPassword() async {
    guard case .token(let token) = source else { return }
    await loadByToken(token, password: password)
  }

  /// 간직 버튼(편지 끝·닫힘 예고·잠김 화면 공통)을 보일지 — 로그인 + (잔액 있음 || 유료 스위치 || 관리자).
  /// 계약 "받은 사람의 간직하기" 앱 규칙. 잔액이 0이면 누를 때 편지권 화면으로 간다.
  var canKeep: Bool {
    guard ticketUsecase != nil, let entitlements else { return false }
    return entitlements.tickets > 0 || entitlements.showsTicketUI
  }

  /// 받은 사람에게 보일 "곧 닫혀요" 남은 일수(0 = 오늘). 토큰 수신에서만, 간직한 뒤엔 없다.
  /// 며칠 전부터 보일지는 서버의 `warn_days`(권한을 못 받으면 기본 2).
  func closingSoonDays(_ payload: LetterPayload) -> Int? {
    guard case .token = source, !isKept else { return nil }
    return payload.closingSoonDays(warnDays: entitlements?.warnDays ?? LetterAccessCountdown.defaultWarnDays)
  }

  /// 편지 끝 안내의 날짜 — 로그인 토큰 수신 + 아직 영구가 아니고 열려 있는(access_until 있음) 편지만.
  /// 간직한 뒤에는 nil이 아니어도 화면은 "간직한 편지예요"를 보인다(`isKept`).
  func openUntil(_ payload: LetterPayload) -> Date? {
    guard case .token = source, ticketUsecase != nil, !payload.isPermanent else { return nil }
    return payload.accessUntil
  }

  /// 받은 편지를 편지권으로 간직한다(열린 편지·잠긴 편지 모두). 잠김 화면이었다면 같은 편지를 다시 열고,
  /// 읽던 중이면 본문을 그대로 둔다. 잔액이 없으면 구매 UI가 있는 계정은 `onNoTicket`(편지권 화면)으로, 아니면 문구로 알린다.
  func keep(onNoTicket: () -> Void) async {
    guard case .token(let token) = source, let ticketUsecase, !isKeeping else { return }
    isKeeping = true
    keepErrorMessage = nil
    defer { isKeeping = false }
    do {
      try await ticketUsecase.keepReceived(token: token, password: lastPassword)
      isKept = true
      if case .letterLocked = state {
        await loadByToken(token, password: lastPassword)
      }
    } catch let error as MutterError where error.define == .noTicket {
      if entitlements?.showsPurchaseUI == true {
        onNoTicket()
      } else {
        keepErrorMessage = error.userMessage
      }
    } catch {
      keepErrorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }

  /// "편지 열기 ▶" — 사용자 제스처에서 재생 시작 + 읽음 기록(수신 경험 비방해, 실패 무시).
  func open() async {
    isOpened = true
    player.start()
    if case .token(let token) = source {
      try? await receiptUsecase.recordOpen(token: token)
    }
  }

  // MARK: - Private

  private func loadByToken(_ token: String, password: String?) async {
    state = .loading
    lastPassword = password
    do {
      let payload = try await deliveryUsecase.open(token: token, password: password)
      // 서버가 열람 시 자동 저장(마이그레이션 0022) — 인증 사용자라면 이미 저장됨.
      if inboxUsecase != nil { savedToInbox = true }
      // 간직 버튼·닫힘 예고 일수 판단용 — 본문 표시를 늦추지 않게 함께 받는다.
      async let entitlementsTask = loadEntitlements()
      await present(payload, password: password)
      entitlements = await entitlementsTask
    } catch let error as MutterError {
      switch error.define {
      case .wrongPassword:
        state = .passwordRequired
      case .linkNotYetRevealed(let date):
        state = .revealPending(date)
      case .loginRequired:
        state = .loginRequired(await cover(token))
      case .letterLocked(let deleteAt):
        async let entitlementsTask = loadEntitlements()
        let cover = await cover(token)
        entitlements = await entitlementsTask
        state = .letterLocked(cover, deleteAt)
      default:
        state = .failed(error.userMessage)
      }
    } catch {
      state = .failed(L10n.viewerErrorLoad)
    }
  }

  /// 봉투(제목·보낸 사람). 실패하면 빈 봉투 — 화면은 기본 문구로 그린다.
  private func cover(_ token: String) async -> LetterCover {
    (try? await letterAccessUsecase.cover(token: token)) ?? .sealed
  }

  /// 편지권 UI 노출 판단용. 실패(배포 전 RPC 없음 포함)하면 nil — 편지권 UI를 숨긴다.
  private func loadEntitlements() async -> Entitlements? {
    guard let ticketUsecase else { return nil }
    return try? await ticketUsecase.entitlements()
  }

  private func loadMyLetter(_ id: String) async {
    state = .loading
    do {
      guard let letter = try await letterUsecase.letter(id: id) else {
        state = .failed(L10n.viewerErrorNotFound)
        return
      }
      let payload = LetterPayload(
        id: letter.id,
        title: letter.title,
        blocks: letter.blocks,
        templateId: letter.templateId,
        cue: letter.cue,
        audioDisabled: false
      )
      await present(payload, password: nil)
    } catch let error as MutterError {
      state = .failed(error.userMessage)
    } catch {
      state = .failed(L10n.viewerErrorLoad)
    }
  }

  /// 편지지에 넘길 블록 — 사진은 받아 둔 서명 URL을 붙이고, 캐시 키는 경로로 둔다.
  func paperBlocks(_ payload: LetterPayload) -> [LetterPaperBlock] {
    payload.blocks.map { block in
      switch block {
      case .text(let text):
        return .text(text)
      case .photo(let photo):
        return .photo(
          id: photo.id,
          url: photo.path.flatMap { photoURLs[$0] },
          cacheKey: photo.path,
          aspectRatio: photo.height > 0 ? CGFloat(photo.width) / CGFloat(photo.height) : 0
        )
      }
    }
  }

  private func present(_ payload: LetterPayload, password: String?) async {
    state = .ready(payload, LetterTheme.theme(id: payload.templateId))
    // 서명 URL과 오디오 준비는 서로 독립이라 함께 진행한다.
    async let photos: Void = loadPhotoURLs(for: payload, password: password)
    // 무음0: 오디오가 꺼진 편지가 아니면 큐를 준비(SC 실패 시 CC0 폴백).
    if !payload.audioDisabled, let cue = payload.cue {
      await player.prepare(cue: cue)
    }
    await photos
  }

  /// 본문을 연 것과 같은 모드(토큰+암호 / 소유자)로 서명 URL을 한 번 받는다.
  /// 실패해도 본문은 그대로 보여야 하므로 에러를 올리지 않고 플레이스홀더로 둔다.
  private func loadPhotoURLs(for payload: LetterPayload, password: String?) async {
    guard !payload.blocks.photoPaths.isEmpty else { return }
    let urls: [String: URL]?
    switch source {
    case .token(let token):
      urls = try? await letterUsecase.photoURLs(token: token, password: password)
    case .myLetter(let id):
      urls = try? await letterUsecase.photoURLs(letterId: id)
    }
    photoURLs = urls ?? [:]
  }
}
