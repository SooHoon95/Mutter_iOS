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

/// 단락의 사진 jsonb(웹 `Paragraph.photo`). 세 플랫폼 공통 계약 — `{ path, width, height }`.
struct ParagraphPhotoDTO: Codable {
  let path: String
  let width: Int
  let height: Int

  init(path: String, width: Int, height: Int) {
    self.path = path
    self.width = width
    self.height = height
  }

  enum CodingKeys: String, CodingKey { case path, width, height }

  /// 웹(JS)이 크기를 실수로 쓸 수 있어 정수·실수를 모두 받는다. 크기 하나 때문에 편지 전체 디코드가 깨지면 안 된다.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    path = try c.decode(String.self, forKey: .path)
    width = Self.decodeDimension(c, .width)
    height = Self.decodeDimension(c, .height)
  }

  private static func decodeDimension(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
    if let value = try? c.decode(Int.self, forKey: key) { return value }
    if let value = try? c.decode(Double.self, forKey: key) { return Int(value.rounded()) }
    return 0
  }
}

/// 단락 jsonb(웹 Paragraph). `paragraphs` JSONB 배열의 요소.
/// `photo`가 있으면 사진 단락이다(text = "", cue 없음).
struct ParagraphDTO: Codable {
  let id: String
  let order: Int
  let text: String
  let cue: MusicCueDTO?
  let photo: ParagraphPhotoDTO?

  init(id: String, order: Int, text: String, cue: MusicCueDTO?, photo: ParagraphPhotoDTO? = nil) {
    self.id = id
    self.order = order
    self.text = text
    self.cue = cue
    self.photo = photo
  }

  enum CodingKeys: String, CodingKey { case id, order, text, cue, photo }

  /// 사진 단락은 다른 클라이언트가 text를 생략할 수 있어 빈 문자열로 받는다.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    order = try c.decode(Int.self, forKey: .order)
    text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    cue = try c.decodeIfPresent(MusicCueDTO.self, forKey: .cue)
    photo = try c.decodeIfPresent(ParagraphPhotoDTO.self, forKey: .photo)
  }
}

/// 웹의 `paragraphs[]`(단락별 큐·사진) ↔ Mutter의 `blocks`+단일 `cue` 변환.
/// PRD v5 단일트랙 피벗: 편지 1통 = 본문 1장 + 음악 1곡. DB 계약(jsonb)은 웹과 동일하게 유지하되,
/// 도메인에서는 텍스트·사진 블록과 단일 큐로 다룬다.
enum LetterContentCodec {
  /// 단락 배열 → 블록. 연속된 텍스트 단락은 빈 줄로 이어 하나의 텍스트 블록으로 합친다
  /// (편집기에서 텍스트 칸 하나가 사진 사이 구간 하나에 대응하도록).
  /// 중간의 빈 단락은 작성자가 넣은 여분의 빈 줄이라 그대로 잇고, 블록 앞뒤의 공백만 걷어낸다
  /// (사진만 있는 편지의 큐 자리채움 단락은 이렇게 사라진다).
  static func blocks(from paragraphs: [ParagraphDTO]) -> [LetterBlock] {
    var blocks: [LetterBlock] = []
    for paragraph in paragraphs.sorted(by: { $0.order < $1.order }) {
      if let photo = paragraph.photo {
        blocks.append(.photo(LetterPhoto(id: paragraph.id, path: photo.path, width: photo.width, height: photo.height)))
        continue
      }
      let text = trimmingTrailingWhitespace(paragraph.text)
      if case .text(let previous) = blocks.last {
        blocks[blocks.count - 1] = .text(previous + "\n\n" + text)
      } else {
        blocks.append(.text(text))
      }
    }
    return blocks.compactMap { block in
      guard case .text(let text) = block else { return block }
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : .text(trimmed)
    }
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

  /// 블록+큐 → 단락 배열(저장용). 텍스트 블록은 빈 줄(\n\n)로 나눠 단락으로, 사진 블록은 사진 단락으로 만든다.
  /// 큐는 첫 텍스트 단락에 붙는다. 텍스트가 하나도 없으면 큐를 실을 빈 텍스트 단락을 맨 앞에 둔다.
  /// 아직 업로드되지 않은(path 없는) 사진은 저장할 수 없으므로 건너뛴다.
  static func paragraphs(blocks: [LetterBlock], cue: MusicCue?) -> [ParagraphDTO] {
    enum Item {
      case text(String)
      case photo(id: String, ParagraphPhotoDTO)
    }

    var items: [Item] = []
    for block in blocks {
      switch block {
      case .text(let text):
        // 빈 조각은 버리지 않는다 — 빈 줄을 여러 번 넣은 자리는 빈 단락("")이나 "\n"으로 시작하는 단락으로 남아
        // 편지지에서 그만큼 빈 줄로 보인다(구 형식과 같은 저장 모양). 조각 끝 공백만 걷고(공백뿐인 줄은 "")
        // 앞 들여쓰기·개행은 둔다. 웹·Android 코덱과 동일.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        items += trimmed.components(separatedBy: "\n\n").map { Item.text(trimmingTrailingWhitespace($0)) }
      case .photo(let photo):
        guard let path = photo.path else { continue }
        items.append(.photo(id: photo.id, ParagraphPhotoDTO(path: path, width: photo.width, height: photo.height)))
      }
    }
    let hasText = items.contains { if case .text = $0 { return true } else { return false } }
    if !hasText { items.insert(.text(""), at: 0) }

    var cueAttached = false
    return items.enumerated().map { index, item in
      switch item {
      case .text(let text):
        let attach = !cueAttached
        cueAttached = true
        return ParagraphDTO(id: UUID().uuidString, order: index, text: text, cue: attach ? cue.map(toDTO) : nil)
      case .photo(let id, let photo):
        return ParagraphDTO(id: id, order: index, text: "", cue: nil, photo: photo)
      }
    }
  }

  private static func trimmingTrailingWhitespace(_ text: String) -> String {
    String(text.reversed().drop(while: \.isWhitespace).reversed())
  }

  private static func toDTO(_ cue: MusicCue) -> MusicCueDTO {
    MusicCueDTO(sourceType: cue.source.rawValue, ref: cue.ref, startMs: cue.startMs, title: cue.title, author: cue.author, sourceUrl: cue.sourceUrl)
  }
}
