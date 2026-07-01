import Foundation

/// OAuth 리다이렉트 등 딥링크 URL을 처리하는 계약(Mercury `DeeplinkHandlable` 대응).
/// 각 소셜 SDK 핸들러가 구현하고, `OauthDeepLinkHandler`가 순회하며 처리자를 찾는다.
public protocol DeeplinkHandlable {
  /// URL을 처리했으면 true(내 담당), 아니면 false(다음 핸들러로 넘김).
  func handle(url: URL) -> Bool
}
