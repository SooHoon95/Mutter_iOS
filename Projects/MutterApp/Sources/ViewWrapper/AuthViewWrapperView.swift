import SwiftUI

import AppFoundation
import AuthFeature
import Domain
import Infrastructure
import Router

/// 인증(로그인) 화면 브리지. `AuthViewable`로 `MainView`의 signin 단계에 주입된다.
/// usecase는 `init`에서 생성자 주입으로 조립하고, 인증/온보딩 완료는 `onComplete`로 합성 루트에 통지한다.
///
/// 흐름:
///   1. .signIn  — 로그인 화면 표시
///   2. onAuthenticated 콜백 → 닉네임 유무 확인
///      - 닉네임 없음 → .onboardNickname 화면으로 전환 (EC-4.6)
///      - 닉네임 있음 → onComplete 즉시 호출
struct AuthViewWrapperView: View, AuthViewable {
  /// 래퍼 내부 화면 단계
  private enum WrapperStep {
    case signIn
    case onboardNickname
  }

  private let onComplete: (() -> Void)?
  private let authUsecase: AuthUsecasable
  private let profileUsecase: ProfileUsecasable

  @State private var step: WrapperStep = .signIn

  init(onComplete: (() -> Void)?) {
    self.onComplete = onComplete
    self.authUsecase = AuthUsecase(repository: AuthRepository())
    self.profileUsecase = ProfileUsecase(repository: ProfileRepository())
  }

  var body: some View {
    switch step {
    case .signIn:
      AuthViewFactory(
        authUsecase: authUsecase,
        profileUsecase: profileUsecase,
        onAuthenticated: { Task { await handleAuthenticated() } },
        onOnboarded: { onComplete?() }
      ).makeView(.signIn)
    case .onboardNickname:
      AuthViewFactory(
        authUsecase: authUsecase,
        profileUsecase: profileUsecase,
        onAuthenticated: { Task { await handleAuthenticated() } },
        onOnboarded: { onComplete?() }
      ).makeView(.onboardNickname)
    }
  }

  /// 로그인 성공 후 닉네임 유무를 확인해 온보딩 게이트를 결정한다.
  /// 웹(Home.tsx)의 `needsName = !profile?.nickname?.trim()` 로직과 동일한 의미.
  private func handleAuthenticated() async {
    let profile = try? await profileUsecase.myProfile()
    let needsNickname = profile?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    if needsNickname {
      step = .onboardNickname
    } else {
      onComplete?()
    }
  }
}
