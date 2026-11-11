import Foundation

/// restore_inbox_items·purge_inbox_items·get_letter_access_states RPC 파라미터(`p_letter_ids uuid[]`).
struct LetterIdsParams: Encodable {
  let letterIds: [String]

  enum CodingKeys: String, CodingKey {
    case letterIds = "p_letter_ids"
  }
}
