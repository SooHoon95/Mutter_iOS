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
  private var cancellables = Set<AnyCancellable>()

  var isLoggedInStream: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
  var isLoggedIn: Bool { subject.value }

  init(authUsecase: AuthUsecasable) {
    self.authUsecase = authUsecase
    observeUnauthorized()
  }

  /// 서버가 세션을 401(JWT 만료/무효)로 거부하면(데이터 레이어가 방송) 로그아웃해 온보딩으로 되돌린다.
  /// 이미 미로그인 상태면 무시한다(로그인 시도 중의 오류에 오작동하지 않도록).
  private func observeUnauthorized() {
    NotificationCenter.default
      .publisher(for: SessionInvalidation.didDetectUnauthorized)
      .sink { [weak self] _ in
        Task { @MainActor in
          guard let self, self.subject.value else { return }
          await self.signOut()
        }
      }
      .store(in: &cancellables)
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
