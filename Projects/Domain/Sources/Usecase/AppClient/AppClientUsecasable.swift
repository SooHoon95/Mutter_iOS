import Foundation

/// 사용자가 지금 쓰는 앱 버전을 서버에 알린다(로그인 상태가 될 때마다).
public protocol AppClientUsecasable {
  func report(appVersion: String, build: String?) async throws
}
