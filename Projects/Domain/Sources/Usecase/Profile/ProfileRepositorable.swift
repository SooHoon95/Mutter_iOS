import Foundation

/// 프로필 데이터 접근 프로토콜(구현은 Infrastructure — `profiles` 테이블 + delete_my_account RPC).
public protocol ProfileRepositorable {
  func myProfile() async throws -> Profile?
  func updateNickname(_ nickname: String) async throws
  func deleteAccount() async throws
}
