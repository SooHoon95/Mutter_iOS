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
  /// 트랙 제목(oEmbed). nil = 레거시/웹 생성 편지 → 뷰어에서 "SoundCloud 트랙" 폴백.
  public let title: String?
  /// 트랙 작성자(oEmbed). 있으면 플레이어 바 subtitle.
  public let author: String?

  public init(source: Source, ref: String, startMs: Int? = nil, title: String? = nil, author: String? = nil) {
    self.source = source
    self.ref = ref
    self.startMs = startMs
    self.title = title
    self.author = author
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

/// 홈 목록용 편지 + 발송 여부(운용 파생 상태). "발송됨"은 Letter의 본질 속성이 아니라
/// delivery_links/타인 inbox 존재로 판정되는 파생값이라, Letter에 넣지 않고 별도 read-model로 둔다(클린 아키텍처).
public struct LetterWithStatus: Equatable {
  public let letter: Letter
  /// 한 번이라도 전달됨(전달 링크 발급 또는 연결 상대 직접 발송). false = 임시저장.
  public let isSent: Bool

  public init(letter: Letter, isSent: Bool) {
    self.letter = letter
    self.isSent = isSent
  }
}
