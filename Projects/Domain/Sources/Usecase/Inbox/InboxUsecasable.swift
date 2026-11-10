import Foundation

/// 받은함 유스케이스 — 편지 보관/조회/삭제 + 받은 편지 삭제함(복구·영구 삭제).
public protocol InboxUsecasable {
  func save(token: String) async throws
  func myInbox() async throws -> [InboxItem]
  /// 받은 편지함에서 뺀다(삭제함으로 30일 보관). 한 통·여러 통 공통.
  func remove(letterIds: [String]) async throws
  func deletedInbox() async throws -> [DeletedInboxItem]
  @discardableResult
  func restore(letterIds: [String]) async throws -> Int
  @discardableResult
  func purge(letterIds: [String]) async throws -> Int
}
