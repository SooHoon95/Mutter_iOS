import Foundation

import Domain

/// get_my_deleted_inbox RPC row — 받은 편지 삭제함(letter_id·token·title·sender_id·sender_nickname·deleted_at·purge_at).
struct DeletedInboxRow: Decodable {
  let letterId: String
  let token: String
  let title: String?
  let senderId: String?
  let senderNickname: String?
  let deletedAt: Date
  let purgeAt: Date

  enum CodingKeys: String, CodingKey {
    case token, title
    case letterId = "letter_id"
    case senderId = "sender_id"
    case senderNickname = "sender_nickname"
    case deletedAt = "deleted_at"
    case purgeAt = "purge_at"
  }

  func toDomain() -> DeletedInboxItem {
    DeletedInboxItem(
      letterId: letterId,
      token: token,
      title: title ?? "",
      senderId: senderId,
      senderNickname: senderNickname,
      deletedAt: deletedAt,
      purgeAt: purgeAt
    )
  }
}
