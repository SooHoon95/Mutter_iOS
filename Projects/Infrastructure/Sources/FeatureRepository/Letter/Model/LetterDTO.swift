import Foundation

import Domain

/// letters 테이블 row(조회용). paragraphs는 jsonb(단락별 큐) — 도메인에선 단일 body+cue로 평탄화.
struct LetterRow: Decodable {
  let id: String
  let ownerId: String
  let title: String
  let paragraphs: [ParagraphDTO]
  let templateId: String

  enum CodingKeys: String, CodingKey {
    case id, title, paragraphs
    case ownerId = "owner_id"
    case templateId = "template_id"
  }

  func toDomain() -> Letter {
    Letter(
      id: id,
      title: title,
      body: LetterContentCodec.body(from: paragraphs),
      templateId: templateId,
      cue: LetterContentCodec.cue(from: paragraphs)
    )
  }
}

/// letters insert 페이로드(owner_id는 세션에서 주입).
struct LetterInsertDTO: Encodable {
  let ownerId: String
  let title: String
  let paragraphs: [ParagraphDTO]
  let templateId: String

  enum CodingKeys: String, CodingKey {
    case title, paragraphs
    case ownerId = "owner_id"
    case templateId = "template_id"
  }
}

/// letters update 페이로드.
struct LetterUpdateDTO: Encodable {
  let title: String
  let paragraphs: [ParagraphDTO]
  let templateId: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case title, paragraphs
    case templateId = "template_id"
    case updatedAt = "updated_at"
  }
}
