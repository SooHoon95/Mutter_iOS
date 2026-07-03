import Foundation

/// 편지 — 본문 1장 + 음악 1곡(cue). 웹 `Letter`와 동일 계약.
/// 본문은 화면에서 빈 줄 기준 단락으로 렌더된다(저장 시 `paragraphs jsonb` 변환은 Infrastructure 담당).
public struct Letter: Identifiable, Equatable {
  public let id: String
  public var title: String
  public var body: String
  public var templateId: String
  /// 음악 큐(SoundCloud). nil = 음악 없는 편지(무음 허용 — CC0 폴백 제거됨).
  public var cue: MusicCue?

  public init(id: String, title: String, body: String, templateId: String, cue: MusicCue? = nil) {
    self.id = id
    self.title = title
    self.body = body
    self.templateId = templateId
    self.cue = cue
  }
}

/// 음악 큐 — 한 곡의 출처/참조/시작 지점.
public struct MusicCue: Equatable {
  public enum Source: String, Equatable {
    case soundcloud
    case hosted
  }

  public let source: Source
  /// soundcloud=트랙 URL, hosted=Storage 경로/트랙 id.
  public let ref: String
  /// 시작 오프셋(ms). nil이면 0부터.
  public let startMs: Int?

  public init(source: Source, ref: String, startMs: Int? = nil) {
    self.source = source
    self.ref = ref
    self.startMs = startMs
  }
}

/// 편지 작성/수정 입력값(제작 화면 → Usecase).
public struct LetterDraft: Equatable {
  public var title: String
  public var body: String
  public var templateId: String
  public var cue: MusicCue?

  public init(title: String, body: String, templateId: String, cue: MusicCue? = nil) {
    self.title = title
    self.body = body
    self.templateId = templateId
    self.cue = cue
  }
}

/// 수신 페이로드 — 토큰으로 열람할 때 받는 편지 데이터(발신자 식별정보 제외).
public struct LetterPayload: Equatable {
  public let id: String
  public let title: String
  public let body: String
  public let templateId: String
  public let cue: MusicCue?
  /// 발신자가 오디오를 끈 편지(takedown 등). true면 무음 재생.
  public let audioDisabled: Bool

  public init(
    id: String,
    title: String,
    body: String,
    templateId: String,
    cue: MusicCue?,
    audioDisabled: Bool
  ) {
    self.id = id
    self.title = title
    self.body = body
    self.templateId = templateId
    self.cue = cue
    self.audioDisabled = audioDisabled
  }
}
