import Foundation

import AppFoundation
import Domain

/// 로그인 플로우 상태/로직. 이메일 매직코드(가입 겸용) + 비밀번호 + 소셜.
@MainActor
@Observable
final class AuthModelData {
  /// 플로우 단계.
  enum Step {
    case enterEmail   // 이메일 입력 → 코드 발송
    case enterCode    // 받은 6자리 코드 입력
    case enterPassword // 비밀번호 로그인(기존 계정)
  }

  var step: Step = .enterEmail
  var email = ""
  var code = ""
  var password = ""
  var isLoading = false
  var errorMessage: String?

  private let authUsecase: AuthUsecasable
  /// 인증 성공 시 호출(앱이 메인 탭으로 라우팅).
  private let onAuthenticated: () -> Void

  init(authUsecase: AuthUsecasable, onAuthenticated: @escaping () -> Void) {
    self.authUsecase = authUsecase
    self.onAuthenticated = onAuthenticated
  }

  var isEmailValid: Bool {
    email.contains("@") && email.contains(".")
  }

  /// 이메일로 6자리 코드 발송 → 코드 입력 단계.
  func requestCode() async {
    await run {
      try await authUsecase.requestCode(email: email)
      step = .enterCode
    }
  }

  /// 코드 검증 → 인증 완료.
  func verifyCode() async {
    await run {
      _ = try await authUsecase.verifyCode(email: email, code: code)
      onAuthenticated()
    }
  }

  /// 비밀번호 로그인 → 인증 완료.
  func signInWithPassword() async {
    await run {
      _ = try await authUsecase.signIn(email: email, password: password)
      onAuthenticated()
    }
  }

  /// 소셜 로그인 — 팩토리로 provider 생성 → SDK 인증 → Supabase 교환 → 완료.
  func signInSocial(_ provider: OauthProvider) async {
    await run {
      let credential = try await SignInProviderFactory().createProvider(provider).signIn()
      switch credential {
      case .social(let socialProvider, let token):
        _ = try await authUsecase.signInSocial(provider: socialProvider, token: token)
      case .apple(let idToken, let nonce):
        _ = try await authUsecase.signInApple(idToken: idToken, nonce: nonce)
      }
      onAuthenticated()
    }
  }

  /// 비밀번호 로그인 화면으로 전환.
  func switchToPassword() {
    errorMessage = nil
    step = .enterPassword
  }

  /// 이메일 입력으로 되돌아간다.
  func backToEmail() {
    errorMessage = nil
    code = ""
    password = ""
    step = .enterEmail
  }

  // MARK: - Private

  /// 공통 실행 래퍼 — 로딩/에러 처리.
  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "잠시 후 다시 시도해 주세요."
    }
  }
}
