import Foundation

/// 푸시 토큰 등록 계약(구현은 Infrastructure — FCM 토큰 → push_tokens 테이블).
public protocol PushTokenRegisterable {
  func register(token: String) async throws
  func unregister() async throws
}
