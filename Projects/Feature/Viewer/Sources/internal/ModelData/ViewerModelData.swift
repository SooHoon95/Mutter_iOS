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

  let player: LetterAudioPlayer

  private let source: Source
  private let deliveryUsecase: DeliveryUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterUsecase: LetterUsecasable
  /// nil이면 미인증(능력 부재 = nil, Mercury DI 패턴).
  private let inboxUsecase: InboxUsecasable?

  init(
    source: Source,
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    inboxUsecase: InboxUsecasable?,
    audioUsecase: AudioUsecasable
  ) {
    self.source = source
    self.deliveryUsecase = deliveryUsecase
    self.receiptUsecase = receiptUsecase
    self.letterUsecase = letterUsecase
    self.inboxUsecase = inboxUsecase
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
    do {
      let payload = try await deliveryUsecase.open(token: token, password: password)
      // 서버가 열람 시 자동 저장(마이그레이션 0022) — 인증 사용자라면 이미 저장됨.
      if inboxUsecase != nil { savedToInbox = true }
      await present(payload)
    } catch let error as MutterError {
      switch error.define {
      case .wrongPassword:
        state = .passwordRequired
      case .linkNotYetRevealed(let date):
        state = .revealPending(date)
      default:
        state = .failed(error.userMessage)
      }
    } catch {
      state = .failed(L10n.viewerErrorLoad)
    }
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
        body: letter.body,
        templateId: letter.templateId,
        cue: letter.cue,
        audioDisabled: false
      )
      await present(payload)
    } catch let error as MutterError {
      state = .failed(error.userMessage)
    } catch {
      state = .failed(L10n.viewerErrorLoad)
    }
  }

  private func present(_ payload: LetterPayload) async {
    state = .ready(payload, LetterTheme.theme(id: payload.templateId))
    // 무음0: 오디오가 꺼진 편지가 아니면 큐를 준비(SC 실패 시 CC0 폴백).
    if !payload.audioDisabled, let cue = payload.cue {
      await player.prepare(cue: cue)
    }
  }
}
