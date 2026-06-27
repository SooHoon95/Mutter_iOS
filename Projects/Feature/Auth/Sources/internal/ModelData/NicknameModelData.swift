import Foundation

import AppFoundation
import Domain

/// 가입 후 닉네임 온보딩 상태/로직.
@MainActor
@Observable
final class NicknameModelData {
  var nickname = ""
  var isLoading = false
  var errorMessage: String?

  private let profileUsecase: ProfileUsecasable
  private let onComplete: () -> Void

  init(profileUsecase: ProfileUsecasable, onComplete: @escaping () -> Void) {
    self.profileUsecase = profileUsecase
    self.onComplete = onComplete
  }

  var isValid: Bool {
    !nickname.trimmingCharacters(in: .whitespaces).isEmpty
  }

  func save() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await profileUsecase.updateNickname(nickname)
      onComplete()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "닉네임을 저장하지 못했어요."
    }
  }
}
