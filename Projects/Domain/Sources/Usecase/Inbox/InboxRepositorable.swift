import Foundation

/// 받은함 데이터 접근 프로토콜(구현은 Infrastructure — save_to_inbox/get_my_inbox RPC, 삭제는 inbox 뷰 RLS,
/// 삭제함은 get_my_deleted_inbox·restore_inbox_items·purge_inbox_items RPC).
public protocol InboxRepositorable {
  func save(token: String) async throws
  func myInbox() async throws -> [InboxItem]
  /// 받은 편지함에서 뺀다 — 서버 뷰 트리거가 30일 보관(받은 편지 삭제함)으로 바꾼다.
  func remove(letterIds: [String]) async throws
  /// 받은 편지 삭제함(최근 삭제순).
  func deletedInbox() async throws -> [DeletedInboxItem]
  /// 삭제함에서 되살린다. 되살린 수를 돌려준다.
  @discardableResult
  func restore(letterIds: [String]) async throws -> Int
  /// 받은 편지함에서 영구 삭제(보낸 사람 편지는 그대로). 지운 수를 돌려준다.
  @discardableResult
  func purge(letterIds: [String]) async throws -> Int
}
