import Foundation

/// 인증 데이터 접근 프로토콜(구현은 Infrastructure — Supabase Auth).
public protocol AuthRepositorable {
  func requestCode(email: String) async throws
  func verifyCode(email: String, code: String) async throws -> Session
  func signIn(email: String, password: String) async throws -> Session
  func signInApple(idToken: String, nonce: String) async throws -> Session
  func signInSocial(provider: SocialProvider, token: String) async throws -> Session
  func signOut() async throws
  func currentSession() async -> Session?
}
