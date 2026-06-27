import Foundation

import Domain

/// get_my_inbox RPC 반환 row(보낸이 정보는 도메인에서 미사용 — 표시는 추후 확장).
struct InboxRow: Decodable {
  let letterId: String
  let token: String
  let title: String
  let savedAt: Date

  enum CodingKeys: String, CodingKey {
    case token, title
    case letterId = "letter_id"
    case savedAt = "saved_at"
  }

  func toDomain() -> InboxItem {
    InboxItem(letterId: letterId, token: token, title: title, savedAt: savedAt)
  }
}
