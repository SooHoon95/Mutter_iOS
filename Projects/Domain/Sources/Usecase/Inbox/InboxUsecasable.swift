import Foundation

/// 받은함 유스케이스 — 편지 보관/조회/삭제.
public protocol InboxUsecasable {
  func save(token: String) async throws
  func myInbox() async throws -> [InboxItem]
  func remove(letterId: String) async throws
}
