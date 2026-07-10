import Foundation

/// 푸시 토큰 저장 프로토콜(구현은 Infrastructure — upsert_push_token RPC).
public protocol PushTokenRepositorable {
  /// FCM 등록 토큰을 서버에 upsert. user_id는 서버(auth.uid)가 강제.
  func upsert(token: String, platform: String, deviceId: String?) async throws
}
