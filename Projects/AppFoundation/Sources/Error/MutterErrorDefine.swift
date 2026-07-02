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
  /// 연결되지 않은 상대에게 편지를 보내려 할 때 (EC-3.2)
  case notConnected
  /// 이미 사용된 초대 링크 수락 시도 (EC-2.2)
  case inviteAlreadyUsed
  case server(String)
  case unknown
}
