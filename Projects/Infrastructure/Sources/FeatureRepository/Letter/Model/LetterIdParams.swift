import Foundation

/// restore_letter·purge_letter·get_letter_readers·make_letter_permanent RPC 파라미터(`p_letter_id`).
struct LetterIdParams: Encodable {
  let letterId: String

  enum CodingKeys: String, CodingKey {
    case letterId = "p_letter_id"
  }
}
