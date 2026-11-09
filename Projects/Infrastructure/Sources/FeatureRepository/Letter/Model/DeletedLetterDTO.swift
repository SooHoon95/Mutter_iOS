import Foundation

import Domain

/// get_my_deleted_letters RPC row — 삭제함 목록(id·title·template_id·deleted_at·purge_at).
struct DeletedLetterRow: Decodable {
  let id: String
  let title: String
  let templateId: String
  let deletedAt: Date
  let purgeAt: Date

  enum CodingKeys: String, CodingKey {
    case id, title
    case templateId = "template_id"
    case deletedAt = "deleted_at"
    case purgeAt = "purge_at"
  }

  func toDomain() -> DeletedLetter {
    DeletedLetter(id: id, title: title, templateId: templateId, deletedAt: deletedAt, purgeAt: purgeAt)
  }
}
