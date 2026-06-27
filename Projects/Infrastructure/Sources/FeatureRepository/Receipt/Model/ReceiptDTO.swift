import Foundation

import Domain

/// get_my_letter_opens RPC 반환 row.
struct LetterOpenRow: Decodable {
  let letterId: String
  let openCount: Int
  let lastOpenedAt: Date

  enum CodingKeys: String, CodingKey {
    case letterId = "letter_id"
    case openCount = "open_count"
    case lastOpenedAt = "last_opened_at"
  }

  func toDomain() -> LetterOpenSummary {
    LetterOpenSummary(letterId: letterId, openCount: openCount, lastOpenedAt: lastOpenedAt)
  }
}
