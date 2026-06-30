import SwiftUI

import AppFoundation
import Domain
import Infrastructure
import Profile
import Router

/// 프로필 탭 브리지. profile/auth usecase는 `init`에서 생성자 주입으로 조립하고,
/// **세션은 전역**이라 `sessionManager`만 컨테이너에서 받는다(Mercury 패턴).
/// 로그아웃/탈퇴 시 `onSignedOut`에서 세션을 재확인해 `MainView`가 signin으로 전환되게 한다.
struct ProfileViewWrapperView: View, ProfileViewable {
  @Inject private var sessionManager: SessionManagable
  private let profileUsecase: ProfileUsecasable
  private let authUsecase: AuthUsecasable

  init() {
    self.profileUsecase = ProfileUsecase(repository: ProfileRepository())
    self.authUsecase = AuthUsecase(repository: AuthRepository())
  }

  var body: some View {
    ProfileView(
      profileUsecase: profileUsecase,
      authUsecase: authUsecase,
      onSignedOut: { Task { await sessionManager.refresh() } }
    )
  }
}
