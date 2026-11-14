import Foundation
import PhotosUI
import SwiftUI

import AppFoundation
import Domain
import UIComponent
import AudioSync

/// 편지 제작 — 편지지(테마) 위 본문 작성 + 음악 1곡 + 저장/발송. 이어쓰기·답장 지원.
@MainActor
@Observable
final class ComposeModelData {
  enum Mode {
    case new
    case edit(String)      // 이어쓰기(letterId)
    case reply(String)     // 답장(recipientId preselect)
  }

  var title = ""
  /// 본문 블록(텍스트 칸·사진 칸). 항상 텍스트 칸이 하나 이상 있다.
  var blocks: [ComposeBlock] = [.text("")]
  /// "사진 넣기" 위치 — 마지막으로 포커스된 텍스트 칸. nil이면 맨 끝.
  var lastFocusedTextId: String?
  /// 사진 고르는 중(로드·축소) — 버튼 중복 탭 방지 + 로딩 표시.
  private(set) var isAddingPhotos = false
  /// 저장된 사진의 서명 URL(이어쓰기 때 소유자 모드로 한 번 받는다).
  private(set) var photoURLs: [String: URL] = [:]
  /// 이번 세션에서 고른 사진 미리보기(photo.id 키). 업로드 뒤에도 다시 받지 않도록 유지한다.
  private(set) var previewImages: [String: UIImage] = [:]
  var templateId = LetterTheme.defaultTheme.id
  var cue: MusicCue?
  var soundcloudURL = ""
  /// 인앱 SoundCloud 탐색 시트 표시 여부.
  var showSoundCloudPicker = false

  var isSaving = false
  var errorMessage: String?
  var savedToast = false

  // MARK: - 보내기 시트(저장 후 발급/발송)
  var showSendSheet = false
  private(set) var sentLetterId: String?   // 시트 대상 편지 id(저장으로 확정).
  var usePassword = true                    // 전달 링크 암호 기본 ON(기본값이 프라이버시).
  var password = ""
  var issuedLink: DeliveryLink?             // 발급된 전달 링크. 암호·예약 여부가 공유 문구에 쓰인다.
  var issuedLinkURL: String? { issuedLink.map { "\(linkBaseURL)/l/\($0.token)" } }
  var isIssuing = false
  var connections: [Connection] = []        // 연결된 사람(독점 1:1 — 0 또는 1).
  var isSending = false                     // 연결 상대 직접 발송 중.

  // 보내기 전 선택(계약 "보내기 전 선택(보낸 사람)") — 조회 실패면 nil/false라 선택 카드 없이 지금처럼 보인다.
  private(set) var sendAccessState: LetterAccessState?
  private(set) var sendEntitlements: Entitlements?
  private(set) var sendHasLinks = false
  /// 이 시트에서 "{n}일 편지로 보내기"를 골랐는지 — 시트를 새로 열면 다시 묻는다.
  var choseFreeDays = false
  var isMakingPermanent = false
  /// 편지권 화면으로 가려고 시트를 닫는 중 — 다 닫힌 뒤 화면이 편지권으로 보낸다(시트 위로는 push가 안 보인다).
  @ObservationIgnored private var pendingTicketsNavigation = false
  /// 편지권 화면에서 돌아오면 같은 편지로 시트를 다시 연다(선택 카드 그대로).
  @ObservationIgnored private var reopenSendAfterTickets = false
  /// 영구 편지를 보내려고 편지권 구매 화면에 갔다 — 돌아와 편지권이 있으면 이어서 영구로 만든다.
  @ObservationIgnored private var wantsPermanentAfterPurchase = false

  let player: LetterAudioPlayer

  private var mode: Mode                     // 첫 저장 후 .edit로 승격(중복 생성 방지).
  private let replyRecipientId: String?      // 답장 대상 — mode 승격과 무관하게 isReply/발송 타깃 유지.
  private let letterUsecase: LetterUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let deliveryUsecase: DeliveryUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable
  private let audioUsecase: AudioUsecasable
  private let linkBaseURL: String
  private let onDone: () -> Void

  init(
    mode: Mode,
    letterUsecase: LetterUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void
  ) {
    self.mode = mode
    if case .reply(let recipientId) = mode { self.replyRecipientId = recipientId } else { self.replyRecipientId = nil }
    self.letterUsecase = letterUsecase
    self.connectionUsecase = connectionUsecase
    self.deliveryUsecase = deliveryUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
    self.audioUsecase = audioUsecase
    self.linkBaseURL = linkBaseURL
    self.player = LetterAudioPlayer(audioUsecase: audioUsecase)
    self.onDone = onDone
  }

  /// 전달 링크 발급 가능 여부(암호 ON이면 암호 입력 필수).
  var canIssueLink: Bool { usePassword ? !password.isEmpty : true }

  var theme: LetterTheme { LetterTheme.theme(id: templateId) }
  var allThemes: [LetterTheme] { LetterTheme.all }
  var isReply: Bool { replyRecipientId != nil }

  func load() async {
    if case .edit(let id) = mode, let letter = try? await letterUsecase.letter(id: id) {
      title = letter.title
      blocks = Self.editableBlocks(letter.blocks)
      templateId = letter.templateId
      cue = letter.cue
      await loadPhotoURLs(letterId: id, paths: letter.blocks.photoPaths)
      await backfillCueTitleIfNeeded()
    }
  }

  /// 이어쓰기로 열 때, 제목 없이 저장된 레거시 SC 큐를 oEmbed로 보강한다.
  /// 제작자 화면이라 무마찰 예외(수신 뷰어와 달리 재검증 허용) — 다음 저장 때 제목이 지속돼 자가치유된다.
  private func backfillCueTitleIfNeeded() async {
    guard let current = cue, current.source == .soundcloud, current.title == nil else { return }
    if case .ok(let title, let author, _) = await audioUsecase.validateSoundCloud(url: current.ref) {
      cue = MusicCue(
        source: current.source,
        ref: current.ref,
        startMs: current.startMs,
        title: title.isEmpty ? nil : title,
        author: author.isEmpty ? nil : author
      )
    }
  }

  // MARK: - Photos

  var photoCount: Int { blocks.filter { $0.photo != nil }.count }
  var remainingPhotoSlots: Int { max(0, LetterPhoto.maxCount - photoCount) }

  /// PhotosPicker에서 고른 사진을 축소해 마지막 포커스 텍스트 칸 뒤에 넣는다.
  /// 고른 순서대로 사진 칸을 잇고, 뒤에 이어 쓸 빈 텍스트 칸을 둔다(바로 뒤가 텍스트 칸이면 그 칸을 쓴다).
  func addPhotos(_ items: [PhotosPickerItem]) async {
    let picked = Array(items.prefix(remainingPhotoSlots))
    guard !picked.isEmpty, !isAddingPhotos else { return }
    isAddingPhotos = true
    errorMessage = nil
    defer { isAddingPhotos = false }

    var newBlocks: [ComposeBlock] = []
    for item in picked {
      guard let data = try? await item.loadTransferable(type: Data.self),
            let output = await Task.detached(operation: { PhotoJPEGEncoder.encode(data) }).value else {
        errorMessage = L10n.composeErrorPhotoLoad
        continue
      }
      let photo = LetterPhoto(width: output.width, height: output.height, pendingJPEG: output.jpeg)
      previewImages[photo.id] = UIImage(data: output.jpeg)
      newBlocks.append(.photo(photo))
    }
    guard !newBlocks.isEmpty else { return }

    let insertAt = lastFocusedTextId
      .flatMap { id in blocks.firstIndex { $0.id == id } }
      .map { $0 + 1 } ?? blocks.endIndex
    let nextIsText = insertAt < blocks.endIndex && blocks[insertAt].photo == nil
    if !nextIsText { newBlocks.append(.text("")) }
    blocks.insert(contentsOf: newBlocks, at: insertAt)
  }

  /// 사진 칸을 빼고, 그 때문에 맞닿게 된 두 텍스트 칸은 하나로 합친다(저장 시에도 합쳐지므로 편집 화면을 미리 맞춘다).
  func removePhoto(blockId: String) {
    guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
    blocks.remove(at: index)
    if index > 0, index < blocks.endIndex, blocks[index - 1].photo == nil, blocks[index].photo == nil {
      let merged = [blocks[index - 1].text, blocks[index].text].filter { !$0.isEmpty }.joined(separator: "\n\n")
      blocks[index - 1].text = merged
      if lastFocusedTextId == blocks[index].id { lastFocusedTextId = blocks[index - 1].id }
      blocks.remove(at: index)
    }
  }

  /// 저장된 블록 → 편집 칸. 사진으로 끝나거나 비어 있으면 이어 쓸 빈 텍스트 칸을 붙인다.
  private static func editableBlocks(_ letterBlocks: [LetterBlock]) -> [ComposeBlock] {
    var result = letterBlocks.map(ComposeBlock.init)
    if result.last?.photo != nil || result.isEmpty { result.append(.text("")) }
    return result
  }

  /// 이어쓰기 화면의 저장된 사진 표시용. 실패하면 플레이스홀더로 두고 편집은 계속한다.
  private func loadPhotoURLs(letterId: String, paths: [String]) async {
    guard !paths.isEmpty else { return }
    photoURLs = (try? await letterUsecase.photoURLs(letterId: letterId)) ?? [:]
  }

  /// 업로드로 경로가 채워진 사진을 편집 칸에 반영한다. 저장 중 사용자가 칸을 바꿨을 수 있어 사진 id로 맞춘다.
  private func applySaved(_ saved: [LetterBlock]) {
    let photos = Dictionary(saved.photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    for index in blocks.indices {
      if let id = blocks[index].photo?.id, let updated = photos[id] {
        blocks[index].photo = updated
      }
    }
  }

  func selectTemplate(_ theme: LetterTheme) {
    templateId = theme.id
  }


  /// SC 검증 진행 중(적용 버튼 중복 탭 방지 + 로딩 표시).
  var isApplyingSoundCloud = false

  /// SoundCloud paste-URL을 큐로 적용 — **붙이는 시점에 oEmbed 검증**(웹 scOembed.ts 동형).
  /// 단축링크(on.soundcloud.com)는 위젯이 직접 못 열므로 canonical URL로 변환해 저장하고,
  /// 비공개·임베드 금지·삭제 트랙은 그 자리에서 거른다(발신자가 죽은 링크를 모른 채 보내는 것 방지).
  func applySoundCloudURL() async {
    errorMessage = nil
    let trimmed = soundcloudURL.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !isApplyingSoundCloud else { return }
    isApplyingSoundCloud = true
    defer { isApplyingSoundCloud = false }

    switch await audioUsecase.validateSoundCloud(url: trimmed) {
    case .ok(let title, let author, let canonicalUrl):
      // oEmbed title/author를 cue에 직접 저장 — 뷰어 플레이어 바가 트랙 제목을 표시하도록(MU-1).
      cue = MusicCue(
        source: .soundcloud,
        ref: canonicalUrl,
        startMs: 0,
        title: title.isEmpty ? nil : title,
        author: author.isEmpty ? nil : author,
        sourceUrl: trimmed   // 원본 붙인 공개 URL — 웹 뷰어 출처 링크용(canonical ref는 API JSON).
      )
      soundcloudURL = ""   // 적용됨 — 입력칸을 비워 즉시 피드백.
    case .fail(let reason):
      errorMessage = Self.scErrorMessage(reason)
    }
  }

  /// 인앱 탐색 시트에서 고른 트랙을 붙여넣기와 같은 검증 경로로 적용한다.
  func applyPickedSoundCloud(_ url: URL) async {
    showSoundCloudPicker = false
    soundcloudURL = url.absoluteString
    await applySoundCloudURL()
  }

  static func scErrorMessage(_ reason: ScValidationFailReason) -> String {
    switch reason {
    case .invalidUrl: return L10n.composeErrorInvalidUrl
    case .network: return L10n.composeErrorNetwork
    case .privateTrack: return L10n.composeErrorPrivateTrack
    case .notFound: return L10n.composeErrorNotFound
    case .embedDisabled: return L10n.composeErrorEmbedDisabled
    }
  }

  /// 현재 선택된 음악의 사용자용 이름(명사구). nil이면 미선택.
  var appliedCueLabel: String? {
    guard let cue else { return nil }
    switch cue.source {
    case .soundcloud:
      return cue.title.map { "‘\($0)’" } ?? L10n.composeMusicSoundcloudTrack
    case .hosted:
      return L10n.composeMusicDefault   // 레거시(웹에서 만든 편지) 표기 전용 — 신규 선택 경로 없음.
    }
  }

  private var isPreparingPreview = false

  func previewAudio() async {
    guard let cue else { return }
    if player.isPlaying { player.pause(); return }
    guard !isPreparingPreview else { return }   // 준비 중 중복 탭 방지(소스 중복 로드 레이스).
    isPreparingPreview = true
    defer { isPreparingPreview = false }
    await player.prepare(cue: cue)
    player.play()   // toggle 대신 명시적 play — 준비 후 항상 재생 의도 전달.
  }

  /// 저장(이어쓰기면 update, 아니면 create). 무음0은 usecase가 보장.
  @discardableResult
  func save() async -> String? {
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }
    let draft = LetterDraft(title: title, blocks: blocks.map(\.letterBlock), templateId: templateId, cue: cue)
    do {
      switch mode {
      case .edit(let id):
        applySaved(try await letterUsecase.update(id: id, draft))
        return id
      case .new:
        let letter = try await letterUsecase.create(draft)
        mode = .edit(letter.id)   // 이후 저장은 갱신 — 반복 저장 시 중복 생성 방지.
        applySaved(letter.blocks)
        return letter.id
      case .reply:
        let letter = try await letterUsecase.create(draft)
        mode = .edit(letter.id)   // 답장도 첫 저장 후 갱신 — 중복 생성 방지(isReply는 유지).
        applySaved(letter.blocks)
        return letter.id
      }
    } catch let error as LetterPhotoSaveError {
      // 행은 이미 있으므로 다음 저장은 갱신으로 — 재시도 때 같은 편지가 또 만들어지지 않는다.
      mode = .edit(error.letterId)
      errorMessage = L10n.composeErrorPhotoUpload
      return nil
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorSave
      return nil
    }
  }

  /// 저장 후 닫기.
  func saveAndClose() async {
    if await save() != nil {
      savedToast = true
      onDone()
    }
  }

  /// 답장 발송 — 저장 후, 대상이 현재 내 연결 상대면 링크 없이 직접 전송한다.
  /// 대상이 비연결(과거 링크로만 주고받은 상대 등)이면 직접 발송은 NOT_CONNECTED로 실패하므로,
  /// 전달 링크로 보내도록 시트를 연다(시트 기본 탭='전달 링크'). 웹 Create.tsx의 link 폴백과 동치.
  func sendReply() async {
    guard let recipientId = replyRecipientId else { return }
    guard let letterId = await save() else { return }
    let connected = (try? await connectionUsecase.myConnections()) ?? []
    guard connected.contains(where: { $0.userId == recipientId }) else {
      // 비연결 상대 — 전달 링크로 폴백(연결 안 된 사람에게는 링크로만).
      sentLetterId = letterId
      issuedLink = nil
      password = ""
      usePassword = true
      choseFreeDays = false
      connections = connected
      await loadSendChoice(letterId: letterId)
      showSendSheet = true
      return
    }
    do {
      try await connectionUsecase.send(letterId: letterId, recipientId: recipientId)
      onDone()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorSend
    }
  }

  // MARK: - 보내기 시트

  /// 저장 후 보내기 시트 열기(새 편지/이어쓰기). 연결 상대를 미리 불러온다.
  func saveAndOpenSend() async {
    guard let id = await save() else { return }
    sentLetterId = id
    issuedLink = nil
    password = ""
    usePassword = true
    errorMessage = nil
    choseFreeDays = false
    async let connectionsTask = connectionUsecase.myConnections()
    async let choiceTask: Void = loadSendChoice(letterId: id)
    connections = (try? await connectionsTask) ?? []
    await choiceTask
    showSendSheet = true
  }

  // MARK: - 보내기 전 선택

  /// 선택 카드 — 아직 영구가 아닌 open 편지 + 유료 스위치 + 링크 없음 + 14일을 고르지 않음.
  /// 카드가 떠 있는 동안 시트는 링크 발급·연결 상대 발송을 보이지 않는다.
  var showsSendChoice: Bool {
    sendAccessState?.type == .open
      && sendEntitlements?.paidEnabled == true
      && !sendHasLinks
      && issuedLink == nil
      && !choseFreeDays
  }

  /// 영구로 만든 뒤(또는 처음부터 영구인) 편지의 "영구" 표시 — 편지권 UI가 켜진 계정에서만.
  var showsPermanentBadge: Bool {
    sendAccessState?.type == .permanent && sendEntitlements?.showsTicketUI == true
  }

  /// 영구 선택 시 편지권이 있는지(관리자는 차감 없음). 없으면 편지권 화면으로 보낸다.
  var hasTicketForPermanent: Bool {
    guard let sendEntitlements else { return false }
    return sendEntitlements.tickets > 0 || sendEntitlements.isAdmin
  }

  /// 편지권 1장으로 영구 편지로 만든 뒤 상태를 다시 받는다(카드가 사라지고 "영구"와 발송 방법이 열린다).
  func makePermanent() async {
    guard let id = sentLetterId, !isMakingPermanent else { return }
    isMakingPermanent = true
    errorMessage = nil
    defer { isMakingPermanent = false }
    do {
      try await ticketUsecase.makePermanent(letterId: id)
      await loadSendChoice(letterId: id)
    } catch let error as MutterError where error.define == .noTicket {
      if sendEntitlements?.showsPurchaseUI == true {
        openTicketsFromSend()
      } else {
        errorMessage = error.userMessage
      }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }

  /// 편지권 화면으로 — 시트를 먼저 닫는다. 실제 이동은 시트가 다 닫힌 뒤(`consumeTicketsNavigation`).
  func openTicketsFromSend() {
    pendingTicketsNavigation = true
    showSendSheet = false
  }

  /// 시트가 닫힌 뒤 호출 — 편지권 화면 이동이 예약돼 있으면 true를 돌려주고, 돌아오면 시트를 다시 열게 표시한다.
  func consumeTicketsNavigation() -> Bool {
    guard pendingTicketsNavigation else { return false }
    pendingTicketsNavigation = false
    reopenSendAfterTickets = true
    return true
  }

  /// 영구 편지를 골랐는데 편지권이 없다 — 구매 화면으로 보내고, 사 오면 이어서 영구로 만든다.
  func buyTicketForPermanent() {
    wantsPermanentAfterPurchase = true
    openTicketsFromSend()
  }

  /// 편지권 화면에서 돌아왔으면 잔액을 다시 받고 같은 편지로 시트를 다시 연다.
  /// 영구 편지를 보내려고 사러 갔다 왔고 편지권이 생겼으면, 다시 고르게 하지 않고 바로 영구로 만든다.
  func reopenSendIfNeeded() async {
    guard reopenSendAfterTickets, let id = sentLetterId else { return }
    reopenSendAfterTickets = false
    await loadSendChoice(letterId: id)
    if wantsPermanentAfterPurchase {
      wantsPermanentAfterPurchase = false
      if showsSendChoice && hasTicketForPermanent { await makePermanent() }
    }
    // makePermanent가 다시 구매 화면으로 보냈으면(잔액 경합) 시트를 열지 않는다.
    if !pendingTicketsNavigation { showSendSheet = true }
  }

  /// 선택 카드 판단용 상태·권한·기존 링크. 표시용 부가 정보라 실패하면 조용히 비운다.
  private func loadSendChoice(letterId: String) async {
    async let statesTask = letterAccessUsecase.accessStates(letterIds: [letterId])
    async let entitlementsTask = ticketUsecase.entitlements()
    async let linksTask = deliveryUsecase.links(letterId: letterId)
    sendAccessState = (try? await statesTask)?[letterId]
    sendEntitlements = try? await entitlementsTask
    sendHasLinks = !((try? await linksTask) ?? []).isEmpty
  }

  /// 전달 링크 발급(시트). 무마찰 위해 예약공개는 생략 — 풀옵션은 전달 관리 화면.
  func issueLink() async {
    guard let id = sentLetterId else { return }
    isIssuing = true
    errorMessage = nil
    defer { isIssuing = false }
    do {
      let link = try await deliveryUsecase.issue(
        letterId: id,
        password: usePassword ? password : nil,
        revealAt: nil
      )
      issuedLink = link
      password = ""
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorLinkCreate
    }
  }

  /// 연결된 상대에게 링크 없이 직접 발송(시트). 성공 시 닫고 홈으로.
  func sendToConnection(_ recipientId: String) async {
    guard let id = sentLetterId else { return }
    isSending = true
    errorMessage = nil
    defer { isSending = false }
    do {
      try await connectionUsecase.send(letterId: id, recipientId: recipientId)
      finishSend()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorSend
    }
  }

  /// 보내기 완료 — 시트 닫고 제작 화면도 닫는다.
  func finishSend() {
    showSendSheet = false
    onDone()
  }
}
