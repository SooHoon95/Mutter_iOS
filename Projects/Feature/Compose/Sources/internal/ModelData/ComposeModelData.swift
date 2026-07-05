import Foundation

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
  var content = ""         // 본문(View.body 충돌 회피 위해 content)
  var templateId = LetterTheme.defaultTheme.id
  var cue: MusicCue?
  var soundcloudURL = ""

  var isSaving = false
  var errorMessage: String?
  var savedToast = false

  // MARK: - 보내기 시트(저장 후 발급/발송)
  var showSendSheet = false
  private(set) var sentLetterId: String?   // 시트 대상 편지 id(저장으로 확정).
  var usePassword = true                    // 전달 링크 암호 기본 ON(기본값이 프라이버시).
  var password = ""
  var issuedLink: String?                   // 발급된 전달 링크 전체 URL.
  var isIssuing = false
  var connections: [Connection] = []        // 연결된 사람(독점 1:1 — 0 또는 1).
  var isSending = false                     // 연결 상대 직접 발송 중.

  let player: LetterAudioPlayer

  private var mode: Mode                     // 첫 저장 후 .edit로 승격(중복 생성 방지).
  private let replyRecipientId: String?      // 답장 대상 — mode 승격과 무관하게 isReply/발송 타깃 유지.
  private let letterUsecase: LetterUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let deliveryUsecase: DeliveryUsecasable
  private let audioUsecase: AudioUsecasable
  private let linkBaseURL: String
  private let onDone: () -> Void

  init(
    mode: Mode,
    letterUsecase: LetterUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void
  ) {
    self.mode = mode
    if case .reply(let recipientId) = mode { self.replyRecipientId = recipientId } else { self.replyRecipientId = nil }
    self.letterUsecase = letterUsecase
    self.connectionUsecase = connectionUsecase
    self.deliveryUsecase = deliveryUsecase
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
      content = letter.body
      templateId = letter.templateId
      cue = letter.cue
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

  static func scErrorMessage(_ reason: ScValidationFailReason) -> String {
    switch reason {
    case .invalidUrl: return "SoundCloud 링크가 맞는지 확인해 주세요 (soundcloud.com 주소)."
    case .network: return "네트워크 연결을 확인하고 다시 시도해 주세요."
    case .privateTrack: return "비공개이거나 지역 제한이 있는 트랙이에요. 다른 곡을 골라 주세요."
    case .notFound: return "트랙을 찾을 수 없어요. 링크를 다시 확인해 주세요."
    case .embedDisabled: return "이 트랙은 외부 재생이 허용되지 않아요. 다른 곡을 골라 주세요."
    }
  }

  /// 현재 선택된 음악의 사용자용 이름(명사구). nil이면 미선택.
  var appliedCueLabel: String? {
    guard let cue else { return nil }
    switch cue.source {
    case .soundcloud:
      return cue.title.map { "‘\($0)’" } ?? "SoundCloud 트랙"
    case .hosted:
      return "기본 제공 음악"   // 레거시(웹에서 만든 편지) 표기 전용 — 신규 선택 경로 없음.
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
    let draft = LetterDraft(title: title, body: content, templateId: templateId, cue: cue)
    do {
      switch mode {
      case .edit(let id):
        try await letterUsecase.update(id: id, draft)
        return id
      case .new:
        let letter = try await letterUsecase.create(draft)
        mode = .edit(letter.id)   // 이후 저장은 갱신 — 반복 저장 시 중복 생성 방지.
        return letter.id
      case .reply:
        let letter = try await letterUsecase.create(draft)
        mode = .edit(letter.id)   // 답장도 첫 저장 후 갱신 — 중복 생성 방지(isReply는 유지).
        return letter.id
      }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "저장하지 못했어요."
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
      connections = connected
      showSendSheet = true
      return
    }
    do {
      try await connectionUsecase.send(letterId: letterId, recipientId: recipientId)
      onDone()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "보내지 못했어요."
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
    connections = (try? await connectionUsecase.myConnections()) ?? []
    showSendSheet = true
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
      issuedLink = "\(linkBaseURL)/l/\(link.token)"
      password = ""
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "링크를 만들지 못했어요."
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
      errorMessage = (error as? MutterError)?.userMessage ?? "보내지 못했어요."
    }
  }

  /// 보내기 완료 — 시트 닫고 제작 화면도 닫는다.
  func finishSend() {
    showSendSheet = false
    onDone()
  }
}
