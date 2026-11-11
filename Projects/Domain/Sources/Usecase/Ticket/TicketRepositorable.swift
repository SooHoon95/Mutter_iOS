import Foundation

/// 편지권 데이터 접근 프로토콜(구현은 Infrastructure — get_my_entitlements·get_my_ticket_history·
/// make_letter_permanent·keep_received_letter RPC).
public protocol TicketRepositorable {
  func entitlements() async throws -> Entitlements
  func history() async throws -> [TicketHistoryItem]
  /// 보낸 사람이 자기 편지를 영구로(편지권 1장, 관리자·이미 영구면 차감 없음).
  func makePermanent(letterId: String) async throws
  /// 받은 사람이 잠긴 편지를 편지권으로 간직(성공하면 받은 편지함에 들어간다).
  func keepReceived(token: String, password: String?) async throws
}
