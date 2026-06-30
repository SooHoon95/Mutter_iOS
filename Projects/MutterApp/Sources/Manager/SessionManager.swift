import Combine
import Foundation

import AppFoundation
import Domain

/// 세션 상태 관리자(Mercury `SignInInformationManager` 대응).
/// 현재는 Supabase 세션 기반 — `AuthUsecasable.currentSession()`으로 로그인 여부를 산출해 스트림으로 방출한다.
/// 추후 토큰 저장·자동 로그인·소셜 로그인으로 확장하는 지점.
@MainActor
final class SessionManager: SessionManagable {
  private let authUsecase: AuthUsecasable
  private let subject = CurrentValueSubject<Bool, Never>(false)

  var isLoggedInStream: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
  var isLoggedIn: Bool { subject.value }

  init(authUsecase: AuthUsecasable) {
    self.authUsecase = authUsecase
  }

  func refresh() async {
    let session = await authUsecase.currentSession()
    subject.send(session != nil)
  }

  func signOut() async {
    try? await authUsecase.signOut()
    subject.send(false)
  }
}
