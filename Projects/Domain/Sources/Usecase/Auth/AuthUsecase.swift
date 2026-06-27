import Foundation

/// 인증 유스케이스 구현 — repository 패스스루(인증 로직은 Supabase가 담당).
public final class AuthUsecase: AuthUsecasable {
  private let repository: AuthRepositorable

  public init(repository: AuthRepositorable) {
    self.repository = repository
  }

  public func requestCode(email: String) async throws {
    try await repository.requestCode(email: email)
  }

  public func verifyCode(email: String, code: String) async throws -> Session {
    try await repository.verifyCode(email: email, code: code)
  }

  public func signIn(email: String, password: String) async throws -> Session {
    try await repository.signIn(email: email, password: password)
  }

  public func signInApple(idToken: String, nonce: String) async throws -> Session {
    try await repository.signInApple(idToken: idToken, nonce: nonce)
  }

  public func signInSocial(provider: SocialProvider, token: String) async throws -> Session {
    try await repository.signInSocial(provider: provider, token: token)
  }

  public func signOut() async throws {
    try await repository.signOut()
  }

  public func currentSession() async -> Session? {
    await repository.currentSession()
  }
}
