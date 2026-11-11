import Foundation

import Domain

/// get_my_entitlements RPC 반환 `{is_admin, tickets, paid_enabled, free_days, grace_days}`.
struct EntitlementsDTO: Decodable {
  let isAdmin: Bool
  let tickets: Int
  let paidEnabled: Bool
  let freeDays: Int
  let graceDays: Int

  enum CodingKeys: String, CodingKey {
    case tickets
    case isAdmin = "is_admin"
    case paidEnabled = "paid_enabled"
    case freeDays = "free_days"
    case graceDays = "grace_days"
  }

  func toDomain() -> Entitlements {
    Entitlements(
      isAdmin: isAdmin,
      tickets: tickets,
      paidEnabled: paidEnabled,
      freeDays: freeDays,
      graceDays: graceDays
    )
  }
}

/// get_my_ticket_history RPC 반환 row.
struct TicketHistoryRow: Decodable {
  let createdAt: Date
  let delta: Int
  let reason: String
  let letterTitle: String?

  enum CodingKeys: String, CodingKey {
    case delta, reason
    case createdAt = "created_at"
    case letterTitle = "letter_title"
  }

  func toDomain() -> TicketHistoryItem {
    TicketHistoryItem(
      createdAt: createdAt,
      delta: delta,
      reason: TicketReasonType(rawValue: reason) ?? .unknown,
      letterTitle: letterTitle
    )
  }
}
