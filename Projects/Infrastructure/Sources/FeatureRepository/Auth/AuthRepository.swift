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
    switch socialProvider {
    case .google:
      // provider별 계정 분리 — 네이티브 OIDC 자동링크를 피하려 우리 edge(google-login)를 경유한다.
      return try await signInGoogleEdge(idToken: token)
    case .kakao:
      // 카카오는 Supabase가 idToken을 직접 못 받으므로(내장 OIDC 미지원) 우리 백엔드를 경유한다.
      return try await signInKakao(idToken: token)
    }
  }

  /// 카카오 로그인 — 우리 Edge Function `kakao-login`에 카카오 idToken을 보내면
  /// 서버가 검증·회원매핑 후 세션(access/refresh)을 발급한다. 그 토큰으로 `setSession`해
  /// 로그인 상태를 확립하면 이후 자동 갱신은 SDK가 처리한다(Keychain 보관).
  private func signInKakao(idToken: String) async throws -> Domain.Session {
    struct Request: Encodable { let idToken: String }
    struct Response: Decodable {
      let accessToken: String
      let refreshToken: String
      let userId: String
      enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
      }
    }
    do {
      let res: Response = try await provider.client.functions.invoke(
        "kakao-login",
        options: FunctionInvokeOptions(body: Request(idToken: idToken))
      )
      let session = try await provider.client.auth.setSession(
        accessToken: res.accessToken, refreshToken: res.refreshToken
      )
      return domainSession(from: session)
    } catch let FunctionsError.httpError(_, data) {
      // Edge Function이 코드화한 에러(EMAIL_CONFLICT_DIFFERENT_PROVIDER 등)를 사용자 메시지로 변환.
      throw mapKakaoEdgeError(data)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  private func mapKakaoEdgeError(_ data: Data) -> Error {
    struct EdgeError: Decodable { let error: String }
    let code = (try? JSONDecoder().decode(EdgeError.self, from: data))?.error
    switch code {
    case "EMAIL_CONFLICT_DIFFERENT_PROVIDER":
      return MutterError(.server("이 이메일은 다른 로그인 방식으로 가입돼 있어요. 해당 방식으로 로그인해 주세요."))
    case "EMAIL_UNAVAILABLE":
      return MutterError(.server("카카오 이메일 제공에 동의해야 로그인할 수 있어요."))
    case "INVALID_TOKEN":
      return MutterError(.server("카카오 인증에 실패했어요. 다시 시도해 주세요."))
    default:
      return MutterError(.server("카카오 로그인에 실패했어요."))
    }
  }

  /// 구글 로그인 — Edge Function `google-login`에 idToken을 보내 서버검증·회원매핑 후 세션 발급.
  /// (provider별 계정 분리 — 네이티브 signInWithIdToken 대신 우리 edge 경유.)
  private func signInGoogleEdge(idToken: String) async throws -> Domain.Session {
    struct Request: Encodable { let idToken: String }
    struct Response: Decodable {
      let accessToken: String
      let refreshToken: String
      let userId: String
      enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
      }
    }
    do {
      let res: Response = try await provider.client.functions.invoke(
        "google-login",
        options: FunctionInvokeOptions(body: Request(idToken: idToken))
      )
      let session = try await provider.client.auth.setSession(
        accessToken: res.accessToken, refreshToken: res.refreshToken
      )
      return domainSession(from: session)
    } catch let FunctionsError.httpError(_, data) {
      throw mapGoogleEdgeError(data)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  private func mapGoogleEdgeError(_ data: Data) -> Error {
    struct EdgeError: Decodable { let error: String }
    let code = (try? JSONDecoder().decode(EdgeError.self, from: data))?.error
    switch code {
    case "EMAIL_UNAVAILABLE":
      return MutterError(.server("구글 이메일 제공에 동의해야 로그인할 수 있어요."))
    case "INVALID_TOKEN":
      return MutterError(.server("구글 인증에 실패했어요. 다시 시도해 주세요."))
    default:
      return MutterError(.server("구글 로그인에 실패했어요."))
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
