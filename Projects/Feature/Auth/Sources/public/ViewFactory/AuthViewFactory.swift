import SwiftUI

import Domain
import Router

/// Auth 화면 팩토리(합성 루트가 usecase·콜백 주입). AuthRoute→화면.
public struct AuthViewFactory: ViewFactory {
  private let authUsecase: AuthUsecasable
  private let profileUsecase: ProfileUsecasable
  private let onAuthenticated: () -> Void
  private let onOnboarded: () -> Void

  public init(
    authUsecase: AuthUsecasable,
    profileUsecase: ProfileUsecasable,
    onAuthenticated: @escaping () -> Void,
    onOnboarded: @escaping () -> Void
  ) {
    self.authUsecase = authUsecase
    self.profileUsecase = profileUsecase
    self.onAuthenticated = onAuthenticated
    self.onOnboarded = onOnboarded
  }

  public func makeView(_ route: AuthRoute) -> some View {
    switch route {
    case .signIn:
      AuthView(authUsecase: authUsecase, onAuthenticated: onAuthenticated)
    case .onboardNickname:
      NicknameOnboardView(profileUsecase: profileUsecase, onComplete: onOnboarded)
    }
  }
}
