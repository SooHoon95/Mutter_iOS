import SwiftUI

import AppFoundation
import AuthFeature
import Domain
import Infrastructure
import Router

/// 인증(로그인) 화면 브리지. `AuthViewable`로 `MainView`의 signin 단계에 주입된다.
/// usecase는 `init`에서 생성자 주입으로 조립하고, 인증/온보딩 완료는 `onComplete`로 합성 루트에 통지한다.
struct AuthViewWrapperView: View, AuthViewable {
  private let onComplete: (() -> Void)?
  private let authUsecase: AuthUsecasable
  private let profileUsecase: ProfileUsecasable

  init(onComplete: (() -> Void)?) {
    self.onComplete = onComplete
    self.authUsecase = AuthUsecase(repository: AuthRepository())
    self.profileUsecase = ProfileUsecase(repository: ProfileRepository())
  }

  var body: some View {
    AuthViewFactory(
      authUsecase: authUsecase,
      profileUsecase: profileUsecase,
      onAuthenticated: { onComplete?() },
      onOnboarded: { onComplete?() }
    ).makeView(.signIn)
  }
}
