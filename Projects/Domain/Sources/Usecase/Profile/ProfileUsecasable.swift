import Foundation

/// 프로필 유스케이스 — 닉네임 온보딩/수정, 계정 삭제.
public protocol ProfileUsecasable {
  func myProfile() async throws -> Profile?
  func updateNickname(_ nickname: String) async throws
  func deleteAccount() async throws
}
