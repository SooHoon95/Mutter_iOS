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
  var tracks: [Track] = []

  var isSaving = false
  var errorMessage: String?
  var savedToast = false

  let player: LetterAudioPlayer

  private let mode: Mode
  private let letterUsecase: LetterUsecasable
  private let catalogUsecase: CatalogUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let onDone: () -> Void

  init(
    mode: Mode,
    letterUsecase: LetterUsecasable,
    catalogUsecase: CatalogUsecasable,
    connectionUsecase: ConnectionUsecasable,
    audioUsecase: AudioUsecasable,
    onDone: @escaping () -> Void
  ) {
    self.mode = mode
    self.letterUsecase = letterUsecase
    self.catalogUsecase = catalogUsecase
    self.connectionUsecase = connectionUsecase
    self.player = LetterAudioPlayer(audioUsecase: audioUsecase)
    self.onDone = onDone
  }

  var theme: LetterTheme { LetterTheme.theme(id: templateId) }
  var allThemes: [LetterTheme] { LetterTheme.all }
  var isReply: Bool { if case .reply = mode { return true } else { return false } }

  func load() async {
    tracks = (try? await catalogUsecase.all()) ?? []
    if case .edit(let id) = mode, let letter = try? await letterUsecase.letter(id: id) {
      title = letter.title
      content = letter.body
      templateId = letter.templateId
      cue = letter.cue
    }
  }

  func selectTemplate(_ theme: LetterTheme) {
    templateId = theme.id
  }

  func selectTrack(_ track: Track) {
    cue = MusicCue.hosted(from: track)
    soundcloudURL = ""
  }

  /// SoundCloud paste-URL을 큐로(공식 임베드 전제 — 검증은 추후 oEmbed).
  func applySoundCloudURL() {
    let trimmed = soundcloudURL.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    cue = MusicCue(source: .soundcloud, ref: trimmed, startMs: 0)
  }

  func previewAudio() async {
    guard let cue else { return }
    await player.prepare(cue: cue)
    player.toggle()
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
      case .new, .reply:
        let letter = try await letterUsecase.create(draft)
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

  /// 답장 발송 — 저장 후 연결 상대에게 전송.
  func sendReply() async {
    guard case .reply(let recipientId) = mode else { return }
    guard let letterId = await save() else { return }
    do {
      try await connectionUsecase.send(letterId: letterId, recipientId: recipientId)
      onDone()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "보내지 못했어요."
    }
  }
}
