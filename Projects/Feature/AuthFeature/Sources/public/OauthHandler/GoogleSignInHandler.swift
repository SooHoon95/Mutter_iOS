import Foundation

import Domain

import GoogleSignIn

/// Google OAuth 리다이렉트 처리(Mercury `GoogleSignInHandler` 대응).
/// `OauthDeepLinkHandler`가 `.onOpenURL` URL을 이 핸들러에 넘긴다.
public struct GoogleSignInHandler: DeeplinkHandlable {
  public init() {}

  public func handle(url: URL) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }
}
