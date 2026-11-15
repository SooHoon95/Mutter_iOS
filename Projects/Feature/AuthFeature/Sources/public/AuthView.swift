import SwiftUI

import Domain
import UIComponent

/// 로그인 화면 — 비밀번호 로그인(기본) + 코드 로그인 + 이메일 회원가입 + 소셜. 수신 무마찰 원칙상 가볍게.
/// pre-auth 루트 화면이라 navbar/뒤로가기 없음(항상 AuthViewWrapper로만 표시, push 안 됨).
public struct AuthView: View {
  @State private var model: AuthModelData

  public init(authUsecase: AuthUsecasable, onAuthenticated: @escaping () -> Void) {
    _model = State(initialValue: AuthModelData(authUsecase: authUsecase, onAuthenticated: onAuthenticated))
  }

  public var body: some View {
    GeometryReader { geo in
      ZStack {
        Asset.Colors.ivory.color.ignoresSafeArea()

        // 작은 화면(mini/SE)·키보드에서 컨텐츠가 잘리지 않도록 ScrollView로 감싼다.
        // minHeight=화면높이 → 여백 있으면 Spacer가 중앙 정렬, 넘치면 스크롤.
        ScrollView(showsIndicators: false) {
          VStack(spacing: 20) {
            Spacer(minLength: 0)

            // 로고는 화면 높이의 1/4쯤만 쓴다 — 입력 카드와 소셜 로그인 세 개가 스크롤 없이 한 화면에 들어오게.
            // (작은 화면에서 넘치면 스크롤된다.)
            Asset.Images.onboardingLogo.image
              .resizable()
              .scaledToFit()
              .frame(height: min(220, geo.size.height * 0.24))

            VStack(spacing: 12) {
              switch model.step {
              case .enterPassword: passwordStep
              case .enterEmail: emailStep
              case .signUp: signUpStep
              case .enterCode: codeStep
              case .setPassword: setPasswordStep
              }

              if let message = model.errorMessage {
                Text(message)
                  .fonts(.caption)
                  .foregroundStyle(Asset.Colors.goldDeep.color)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(20)
            .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
            .shadows(.shadowLow)

            // 비밀번호 설정 단계는 이미 로그인된 상태, 회원가입은 이메일 가입 중 — 소셜 버튼을 보이지 않는다.
            if model.step != .setPassword && model.step != .signUp {
              socialSection
            }

            Spacer(minLength: 0)
          }
          .padding(.horizontal, 24)
          .frame(maxWidth: 420)
          .frame(maxWidth: .infinity)
          .frame(minHeight: geo.size.height)
        }
        .scrollDismissesKeyboard(.interactively)
      }
    }
  }

  // MARK: - Steps

  private var emailStep: some View {
    VStack(spacing: 12) {
      field(L10n.authEmail, text: $model.email, keyboard: .emailAddress)
      MutterButton(L10n.authGetCode, isLoading: model.isLoading, isEnabled: model.isEmailValid) {
        Task { await model.requestCode() }
      }
      MutterButton(L10n.authLoginWithPassword, style: .ghost) {
        model.showPasswordLogin()
      }
    }
  }

  private var codeStep: some View {
    VStack(spacing: 12) {
      Text(L10n.authCodeSent(model.email))
        .fonts(.caption)
        .foregroundStyle(Asset.Colors.inkSoft.color)
        .multilineTextAlignment(.center)
      field(L10n.authCodeField, text: $model.code, keyboard: .numberPad)
      MutterButton(L10n.commonConfirm, isLoading: model.isLoading, isEnabled: !model.code.isEmpty) {
        Task { await model.verifyCode() }
      }
      MutterButton(L10n.authReenterEmail, style: .ghost) {
        model.backFromCode()
      }
    }
  }

  private var passwordStep: some View {
    VStack(spacing: 12) {
      field(L10n.authEmail, text: $model.email, keyboard: .emailAddress)
      secureField(L10n.authPassword, text: $model.password, contentType: .password)
      MutterButton(L10n.authLogin, isLoading: model.isLoading, isEnabled: model.isEmailValid && !model.password.isEmpty) {
        Task { await model.signInWithPassword() }
      }
      // 보조 경로 두 개는 낮은 글자 버튼으로 붙여 둔다(큰 버튼 두 개면 사이가 벌어지고 소셜 로그인이 화면 밖으로 밀린다).
      VStack(spacing: 0) {
        linkButton(L10n.authLoginWithCode) { model.showCodeLogin() }
        linkButton(L10n.authSignUpOpen) { model.showSignUp() }
      }
    }
  }

  /// 이메일 회원가입 — 비밀번호를 정하고 코드로 이메일을 인증하면 가입이 끝난다.
  private var signUpStep: some View {
    VStack(spacing: 12) {
      Text(L10n.authSignUpTitle)
        .fonts(.bodyLargeBold)
        .foregroundStyle(Asset.Colors.ink.color)
      field(L10n.authEmail, text: $model.email, keyboard: .emailAddress)
      secureField(L10n.authSetPasswordNew, text: $model.password, contentType: .newPassword)
      secureField(L10n.authSetPasswordConfirm, text: $model.passwordConfirm, contentType: .newPassword)
      MutterButton(L10n.authSignUpRequestCode, isLoading: model.isLoading, isEnabled: model.canRequestSignUpCode) {
        Task { await model.requestSignUpCode() }
      }
      MutterButton(L10n.authBackToLogin, style: .ghost) {
        model.showPasswordLogin()
      }
    }
  }

  /// 코드 로그인 직후 — 비밀번호를 정해 두면 다음부터 비밀번호로 로그인할 수 있다. 건너뛸 수 있다.
  private var setPasswordStep: some View {
    VStack(spacing: 12) {
      Text(L10n.authSetPasswordTitle)
        .fonts(.bodyLargeBold)
        .foregroundStyle(Asset.Colors.ink.color)
      Text(L10n.authSetPasswordGuide)
        .fonts(.caption)
        .foregroundStyle(Asset.Colors.inkSoft.color)
        .multilineTextAlignment(.center)
      secureField(L10n.authSetPasswordNew, text: $model.password, contentType: .newPassword)
      secureField(L10n.authSetPasswordConfirm, text: $model.passwordConfirm, contentType: .newPassword)
      MutterButton(L10n.authSetPasswordSave, isLoading: model.isLoading, isEnabled: model.canSavePassword) {
        Task { await model.saveNewPassword() }
      }
      MutterButton(L10n.authSetPasswordLater, style: .ghost) {
        model.skipPasswordSetup()
      }
      .disabled(model.isLoading)
    }
  }

  // MARK: - Social (Google/Kakao/Apple — 콘솔 키는 Sensitive.xcconfig에서 주입)
  // Mercury 패턴: provider별 버튼(SignInButtonView)을 allCases로 나열.

  private var socialSection: some View {
    VStack(spacing: 8) {
      Text(L10n.commonOr)
        .fonts(.caption)
        .foregroundStyle(Asset.Colors.inkFaint.color)
        .padding(.bottom, 2)
      ForEach(OauthProvider.allCases) { provider in
        SignInButtonView(type: provider) {
          await model.signInSocial(provider)
        }
        .disabled(model.isLoading)
      }
    }
  }

  // MARK: - Helpers

  /// 카드 안의 보조 글자 버튼 — 기본 버튼(54pt)보다 낮게(40pt) 잡아 여러 개를 가깝게 쌓는다.
  private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .fonts(.bodyLargeBold)
        .foregroundStyle(Asset.Colors.ink.color)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
  }

  private func secureField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType) -> some View {
    SecureField(placeholder, text: text)
      .textFieldStyle(.plain)
      .textContentType(contentType)
      .padding(14)
      .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }

  private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
    TextField(placeholder, text: text)
      .textFieldStyle(.plain)
      .keyboardType(keyboard)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .padding(14)
      .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }
}
