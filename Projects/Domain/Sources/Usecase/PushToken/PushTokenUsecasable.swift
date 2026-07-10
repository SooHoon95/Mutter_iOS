import Foundation

/// 푸시 토큰 등록 유스케이스.
public protocol PushTokenUsecasable {
  /// 현재 기기의 FCM 토큰을 서버에 등록(platform=ios 고정).
  func register(token: String, deviceId: String?) async throws
}
