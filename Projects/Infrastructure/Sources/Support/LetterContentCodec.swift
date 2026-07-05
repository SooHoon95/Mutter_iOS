import Foundation

import Domain

/// 음악 큐 jsonb(웹 cue) — 키는 camelCase 그대로(전역 snake 변환 금지).
struct MusicCueDTO: Codable {
  let sourceType: String
  let ref: String
  let startMs: Int?
  /// oEmbed 트랙 제목/작성자 + 원본 공개 URL(신규). optional이라 기존 jsonb(필드 없음)는 nil로 안전 디코드.
  let title: String?
  let author: String?
  let sourceUrl: String?
}

/// 단락 jsonb(웹 Paragraph). `paragraphs` JSONB 배열의 요소.
struct ParagraphDTO: Codable {
  let id: String
  let order: Int
  let text: String
  let cue: MusicCueDTO?
}

/// 웹의 `paragraphs[]`(단락별 큐) ↔ Mutter의 단일 `body`+단일 `cue` 변환.
/// PRD v5 단일트랙 피벗: 편지 1통 = 본문 1장 + 음악 1곡. DB 계약(jsonb)은 웹과 동일하게 유지하되,
/// 도메인에서는 단일 본문/큐로 평탄화한다.
enum LetterContentCodec {
  /// 단락 배열 → 본문 문자열(순서대로 빈 줄로 연결).
  static func body(from paragraphs: [ParagraphDTO]) -> String {
    paragraphs
      .sorted { $0.order < $1.order }
      .map(\.text)
      .joined(separator: "\n\n")
  }

  /// 단락 배열 → 단일 큐(첫 큐 채택).
  static func cue(from paragraphs: [ParagraphDTO]) -> MusicCue? {
    guard let dto = paragraphs.sorted(by: { $0.order < $1.order }).compactMap(\.cue).first else {
      return nil
    }
    return MusicCue(
      source: MusicCue.Source(rawValue: dto.sourceType) ?? .hosted,
      ref: dto.ref,
      startMs: dto.startMs,
      title: dto.title,
      author: dto.author,
      sourceUrl: dto.sourceUrl
    )
  }

  /// 본문+큐 → 단락 배열(저장용). 빈 줄로 분리, 큐는 첫 단락에 부여.
  static func paragraphs(body: String, cue: MusicCue?) -> [ParagraphDTO] {
    let texts = body
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let safeTexts = texts.isEmpty ? [""] : texts

    return safeTexts.enumerated().map { index, text in
      ParagraphDTO(
        id: UUID().uuidString,
        order: index,
        text: text,
        cue: index == 0 ? cue.map(toDTO) : nil
      )
    }
  }

  private static func toDTO(_ cue: MusicCue) -> MusicCueDTO {
    MusicCueDTO(sourceType: cue.source.rawValue, ref: cue.ref, startMs: cue.startMs, title: cue.title, author: cue.author, sourceUrl: cue.sourceUrl)
  }
}
