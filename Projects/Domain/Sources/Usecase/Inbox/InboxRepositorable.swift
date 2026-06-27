import Foundation

/// 받은함 데이터 접근 프로토콜(구현은 Infrastructure — save_to_inbox/get_my_inbox RPC).
public protocol InboxRepositorable {
  func save(token: String) async throws
  func myInbox() async throws -> [InboxItem]
}
