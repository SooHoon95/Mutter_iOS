import Foundation

/// 앱 전역 에러의 의미 분류. 사용자 메시지·복구 분기는 이 케이스로 한다.
public enum MutterErrorDefine: Equatable {
  case network
  case unauthorized
  case notFound
  case rateLimited
  case wrongPassword
  case linkRevoked
  case linkExpired
  case linkNotYetRevealed(Date)
  case server(String)
  case unknown
}
