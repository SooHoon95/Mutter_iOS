import Foundation

/// 인증 유스케이스 — 매직코드/비밀번호/소셜/Apple 로그인.
public protocol AuthUsecasable {
  /// 이메일로 매직 코드 요청.
  func requestCode(email: String) async throws
  /// 매직 코드 검증 → 세션.
  func verifyCode(email: String, code: String) async throws -> Session
  /// 이메일+비밀번호 로그인.
  func signIn(email: String, password: String) async throws -> Session
  /// Apple 로그인(idToken + nonce).
  func signInApple(idToken: String, nonce: String) async throws -> Session
  /// 소셜 로그인(google/kakao).
  func signInSocial(provider: SocialProvider, token: String) async throws -> Session
  /// 로그아웃.
  func signOut() async throws
  /// 현재 세션(없으면 nil).
  func currentSession() async -> Session?
}
