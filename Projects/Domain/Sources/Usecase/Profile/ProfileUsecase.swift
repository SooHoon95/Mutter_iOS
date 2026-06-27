import Foundation

import AppFoundation

/// 프로필 유스케이스 구현.
public final class ProfileUsecase: ProfileUsecasable {
  private let repository: ProfileRepositorable

  public init(repository: ProfileRepositorable) {
    self.repository = repository
  }

  public func myProfile() async throws -> Profile? {
    try await repository.myProfile()
  }

  public func updateNickname(_ nickname: String) async throws {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw MutterError(.server("닉네임을 입력해 주세요."))
    }
    try await repository.updateNickname(trimmed)
  }

  public func deleteAccount() async throws {
    try await repository.deleteAccount()
  }
}
