import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `AuthRepositorable` 구현 — Supabase Auth 래핑. 세션은 SDK가 Keychain에 보관.
/// 매직코드 = signInWithOTP(전송) + verifyOTP(type .email, 검증). 소셜은 OIDC idToken.
public final class AuthRepository: AuthRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func requestCode(email: String) async throws {
    do {
      // "Magic Link" 템플릿의 {{ .Token }}이 6자리 코드로 전송된다. 신규 이메일이면 계정 생성.
      try await provider.client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func verifyCode(email: String, code: String) async throws -> Domain.Session {
    do {
      let response = try await provider.client.auth.verifyOTP(email: email, token: code, type: .email)
      guard let session = response.session else {
        throw MutterError(.unauthorized)
      }
      return domainSession(from: session)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func signIn(email: String, password: String) async throws -> Domain.Session {
    do {
      let session = try await provider.client.auth.signIn(email: email, password: password)
      return domainSession(from: session)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func signInApple(idToken: String, nonce: String) async throws -> Domain.Session {
    do {
      let session = try await provider.client.auth.signInWithIdToken(
        credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
      )
      return domainSession(from: session)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func signInSocial(provider socialProvider: SocialProvider, token: String) async throws -> Domain.Session {
    let oidcProvider: OpenIDConnectCredentials.Provider
    switch socialProvider {
    case .google:
      oidcProvider = .google
    case .kakao:
      // supabase-swift OIDC는 카카오 미지원 — Phase2에서 Kakao SDK + OAuth로 처리.
      throw MutterError(.server("카카오 로그인은 준비 중이에요."))
    }
    do {
      let session = try await provider.client.auth.signInWithIdToken(
        credentials: .init(provider: oidcProvider, idToken: token)
      )
      return domainSession(from: session)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func signOut() async throws {
    do {
      try await provider.client.auth.signOut()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func currentSession() async -> Domain.Session? {
    // 캐시된 로컬 세션(만료 가능). 정밀 검증은 상위에서 필요 시 수행.
    provider.client.auth.currentSession.map(domainSession(from:))
  }

  private func domainSession(from session: Auth.Session) -> Domain.Session {
    Domain.Session(userId: session.user.id.uuidString, email: session.user.email)
  }
}
