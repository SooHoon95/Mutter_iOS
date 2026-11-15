import Foundation

import AppFoundation
import Domain
import UIComponent

/// 로그인 플로우 상태/로직. 비밀번호 로그인(기본) + 코드 로그인 + 이메일 회원가입 + 소셜.
/// 흐름 규칙: docs/specs/2026-11-14-login-password.md (웹·Android 동일).
@MainActor
@Observable
final class AuthModelData {
  /// 플로우 단계.
  enum Step {
    case enterPassword // 비밀번호 로그인(기본 화면)
    case enterEmail   // 코드 로그인 — 이메일 입력 → 코드 발송
    case signUp       // 이메일 회원가입 — 이메일·비밀번호·확인 입력 → 코드 발송
    case enterCode    // 받은 6자리 코드 입력(코드 로그인·회원가입 공통)
    case setPassword  // 코드 로그인 직후 — 비밀번호를 아직 안 정한 이메일 계정(건너뛰기 가능)
  }

  var step: Step = .enterPassword
  var email = ""
  var code = ""
  var password = ""
  /// 비밀번호 설정 단계의 확인 입력.
  var passwordConfirm = ""
  var isLoading = false
  var errorMessage: String?
  /// 회원가입으로 코드를 요청했을 때 입력해 둔 비밀번호 — 코드 인증 직후 저장한다.
  private var pendingSignUpPassword: String?

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

  /// 코드 로그인 — 이메일로 6자리 코드 발송 → 코드 입력 단계.
  func requestCode() async {
    await run {
      try await authUsecase.requestCode(email: email)
      pendingSignUpPassword = nil
      step = .enterCode
    }
  }

  var canRequestSignUpCode: Bool { isEmailValid && canSavePassword }

  /// 회원가입 — 비밀번호 규칙을 먼저 확인하고 코드 발송. 처음 쓰는 이메일이면 이때 계정이 만들어진다.
  /// 비밀번호는 코드 인증으로 세션이 생긴 뒤에야 저장할 수 있어 잠시 들고 있는다(웹 가입과 같은 순서).
  func requestSignUpCode() async {
    if let message = PasswordRule.validate(password, confirm: passwordConfirm) {
      errorMessage = message
      return
    }
    await run {
      try await authUsecase.requestCode(email: email)
      pendingSignUpPassword = password
      step = .enterCode
    }
  }

  /// 코드 검증 → 인증 완료.
  /// - 회원가입이면 입력해 둔 비밀번호를 바로 저장한다. 저장이 실패하면 비밀번호 설정 단계에서 다시 시도하게 한다.
  /// - 코드 로그인이면 직접 정한 비밀번호가 없는 이메일 계정에만 비밀번호 설정 단계를 먼저 보인다.
  /// (세션은 이미 생겼지만 `onAuthenticated` 전까지 앱은 로그인 화면을 유지한다 — MainView는 그 콜백 뒤에 세션을 다시 읽는다.)
  func verifyCode() async {
    await run {
      let session = try await authUsecase.verifyCode(email: email, code: code)
      if let signUpPassword = pendingSignUpPassword {
        pendingSignUpPassword = nil
        do {
          try await authUsecase.setPassword(signUpPassword)
          onAuthenticated()
        } catch let error as MutterError where error.define == .samePassword {
          // 이미 가입된 이메일 + 지금 비밀번호를 그대로 입력 — 비밀번호가 이미 원하는 값이므로 성공으로 본다(Android 동일).
          onAuthenticated()
        } catch {
          password = ""
          passwordConfirm = ""
          step = .setPassword
          errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
        }
      } else if session.isEmailAccount && !session.hasSetPassword {
        password = ""
        passwordConfirm = ""
        step = .setPassword
      } else {
        onAuthenticated()
      }
    }
  }

  var canSavePassword: Bool { !password.isEmpty && !passwordConfirm.isEmpty }

  /// 비밀번호 저장 → 인증 완료. 실패하면 오류만 보이고, "나중에 하기"로 그대로 진입할 수 있다.
  func saveNewPassword() async {
    if let message = PasswordRule.validate(password, confirm: passwordConfirm) {
      errorMessage = message
      return
    }
    await run {
      try await authUsecase.setPassword(password)
      onAuthenticated()
    }
  }

  /// 비밀번호 설정을 건너뛰고 진입.
  func skipPasswordSetup() {
    errorMessage = nil
    onAuthenticated()
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

  /// 비밀번호 로그인(기본 화면)으로.
  func showPasswordLogin() { move(to: .enterPassword) }

  /// 코드 로그인으로.
  func showCodeLogin() { move(to: .enterEmail) }

  /// 이메일 회원가입으로.
  func showSignUp() { move(to: .signUp) }

  /// 코드 입력에서 "이메일 다시 입력" — 회원가입 중이었으면 입력해 둔 비밀번호를 살려 가입 화면으로 돌아간다.
  func backFromCode() {
    errorMessage = nil
    code = ""
    let wasSigningUp = pendingSignUpPassword != nil
    pendingSignUpPassword = nil
    step = wasSigningUp ? .signUp : .enterEmail
  }

  // MARK: - Private

  /// 단계 전환 — 이메일만 남기고 입력·오류를 비운다.
  private func move(to next: Step) {
    errorMessage = nil
    code = ""
    password = ""
    passwordConfirm = ""
    pendingSignUpPassword = nil
    step = next
  }

  /// 공통 실행 래퍼 — 로딩/에러 처리.
  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }
}
