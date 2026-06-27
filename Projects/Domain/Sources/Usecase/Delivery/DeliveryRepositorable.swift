import Foundation

/// 전달 데이터 접근 프로토콜(구현은 Infrastructure — issue_link/get_letter_by_token/revoke_link RPC).
public protocol DeliveryRepositorable {
  func issue(letterId: String, password: String?, revealAt: Date?) async throws -> DeliveryLink
  func revoke(token: String) async throws
  func links(letterId: String) async throws -> [DeliveryLink]
  func open(token: String, password: String?) async throws -> LetterPayload
}
