import Foundation

import AppFoundation
import Domain

/// 프로필 탭 상태/로직 — 닉네임 수정, 로그아웃, 계정 삭제.
@MainActor
@Observable
final class ProfileModelData {
  var nickname = ""
  var isLoading = false
  var errorMessage: String?
  var savedToast = false

  private let profileUsecase: ProfileUsecasable
  private let authUsecase: AuthUsecasable
  private let onSignedOut: () -> Void

  init(
    profileUsecase: ProfileUsecasable,
    authUsecase: AuthUsecasable,
    onSignedOut: @escaping () -> Void
  ) {
    self.profileUsecase = profileUsecase
    self.authUsecase = authUsecase
    self.onSignedOut = onSignedOut
  }

  func load() async {
    let profile = try? await profileUsecase.myProfile()
    nickname = profile?.nickname ?? ""
  }

  func saveNickname() async {
    await run {
      try await profileUsecase.updateNickname(nickname)
      savedToast = true
    }
  }

  func signOut() async {
    await run {
      try await authUsecase.signOut()
      onSignedOut()
    }
  }

  func deleteAccount() async {
    await run {
      try await profileUsecase.deleteAccount()
      try? await authUsecase.signOut()
      onSignedOut()
    }
  }

  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "잠시 후 다시 시도해 주세요."
    }
  }
}
