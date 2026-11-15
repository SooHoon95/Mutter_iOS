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
  /// 이메일(코드·비밀번호) 가입 계정인지. 소셜 계정은 이메일이 내부용이라 비밀번호 기능을 쓰지 않는다.
  public let isEmailAccount: Bool
  /// 사용자가 직접 비밀번호를 정했는지(`user_metadata.password_set`). 코드 가입자는 false.
  /// 표시용 힌트일 뿐 — 웹에서 이 표시 도입 전에 정한 비밀번호는 false로 보인다.
  public let hasSetPassword: Bool

  public init(userId: String, email: String?, isEmailAccount: Bool = false, hasSetPassword: Bool = false) {
    self.userId = userId
    self.email = email
    self.isEmailAccount = isEmailAccount
    self.hasSetPassword = hasSetPassword
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
