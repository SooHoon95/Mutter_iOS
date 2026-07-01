import Foundation

import Domain

import AuthFeature

/// OAuth 리다이렉트 URL을 등록된 소셜 핸들러에 순회 위임한다(Mercury `OauthDeepLinkHandler` 대응).
/// `MainView.onOpenURL`이 이 shared에 URL을 넘기고, 아무도 처리 못하면 false로 앱 딥링크로 폴백한다.
final class OauthDeepLinkHandler {
  static let shared = OauthDeepLinkHandler(handlers: [
    GoogleSignInHandler(),
    KakaoSignInHandler()
  ])

  private let handlers: [DeeplinkHandlable]

  private init(handlers: [DeeplinkHandlable]) {
    self.handlers = handlers
  }

  /// 처리자를 찾으면 true(소셜 콜백 소진), 아니면 false(앱 딥링크로 폴백).
  @discardableResult
  func handle(url: URL) -> Bool {
    for handler in handlers where handler.handle(url: url) {
      return true
    }
    return false
  }
}
