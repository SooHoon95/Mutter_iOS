import Foundation

/// restore_letter·purge_letter RPC 파라미터(`p_letter_id`).
struct LetterIdParams: Encodable {
  let letterId: String

  enum CodingKeys: String, CodingKey {
    case letterId = "p_letter_id"
  }
}
