import Foundation

/// 편지권 유스케이스 — 권한·잔액 조회, 내역, 편지권 사용.
public protocol TicketUsecasable {
  func entitlements() async throws -> Entitlements
  func history() async throws -> [TicketHistoryItem]
  func makePermanent(letterId: String) async throws
  func keepReceived(token: String, password: String?) async throws
}
