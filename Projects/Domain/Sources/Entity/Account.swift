import Foundation

/// 소셜 로그인 제공자(Apple은 전용 메서드).
public enum SocialProvider: String, Equatable {
  case google
  case kakao
}

/// 로그인 세션 — 현재 인증된 사용자.
public struct Session: Equatable {
  public let userId: String
  public let email: String?

  public init(userId: String, email: String?) {
    self.userId = userId
    self.email = email
  }
}

/// 사용자 프로필 — 닉네임(온보딩에서 설정).
public struct Profile: Identifiable, Equatable {
  public let id: String
  public var nickname: String?

  public init(id: String, nickname: String? = nil) {
    self.id = id
    self.nickname = nickname
  }
}
