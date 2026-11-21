import Foundation

/// 앱 버전·플랫폼 보고 프로토콜(구현은 Infrastructure — report_app_client RPC).
public protocol AppClientRepositorable {
  /// 지금 쓰는 앱 버전을 서버에 남긴다. user_id는 서버(auth.uid)가 강제하고, 계정×플랫폼마다 최근 값 하나만 남는다.
  func report(platform: String, appVersion: String, build: String?) async throws
}
