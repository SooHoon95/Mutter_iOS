import Foundation

import Domain

import KakaoSDKAuth

/// Kakao OAuth 리다이렉트 처리(Mercury `KakaoSignInHandler` 대응).
/// 카카오톡 앱 로그인 콜백(kakao{appKey}://…)만 처리하고, 아니면 false로 넘긴다.
public struct KakaoSignInHandler: DeeplinkHandlable {
  public init() {}

  public func handle(url: URL) -> Bool {
    // .onOpenURL은 메인 스레드 → AuthController(@MainActor) 동기 호출.
    MainActor.assumeIsolated {
      guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
      return AuthController.handleOpenUrl(url: url)
    }
  }
}
