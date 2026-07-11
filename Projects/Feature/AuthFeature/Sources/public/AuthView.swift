import SwiftUI

import Domain
import UIComponent

/// 로그인 화면 — 이메일 매직코드(가입 겸용) + 비밀번호. 수신 무마찰 원칙상 가볍게.
/// pre-auth 루트 화면이라 navbar/뒤로가기 없음(항상 AuthViewWrapper로만 표시, push 안 됨).
public struct AuthView: View {
  @State private var model: AuthModelData

  public init(authUsecase: AuthUsecasable, onAuthenticated: @escaping () -> Void) {
    _model = State(initialValue: AuthModelData(authUsecase: authUsecase, onAuthenticated: onAuthenticated))
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 24) {
        Spacer()

        VStack(spacing: 8) {
          Asset.Images.onboardingLogo.image
            .resizable()
            .scaledToFit()
            .frame(height: 300)
        }

        VStack(spacing: 12) {
          switch model.step {
          case .enterEmail: emailStep
          case .enterCode: codeStep
          case .enterPassword: passwordStep
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

        socialSection

        Spacer()
        Spacer()
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: 420)
    }
  }

  // MARK: - Steps

  private var emailStep: some View {
    VStack(spacing: 12) {
      field("이메일", text: $model.email, keyboard: .emailAddress)
      MutterButton("코드 받기", isLoading: model.isLoading, isEnabled: model.isEmailValid) {
        Task { await model.requestCode() }
      }
      MutterButton("비밀번호로 로그인", style: .ghost) {
        model.switchToPassword()
      }
    }
  }

  private var codeStep: some View {
    VStack(spacing: 12) {
      Text("\(model.email)로 보낸 6자리 코드를 입력하세요")
        .fonts(.caption)
        .foregroundStyle(Asset.Colors.inkSoft.color)
        .multilineTextAlignment(.center)
      field("인증 코드", text: $model.code, keyboard: .numberPad)
      MutterButton("확인", isLoading: model.isLoading, isEnabled: !model.code.isEmpty) {
        Task { await model.verifyCode() }
      }
      MutterButton("이메일 다시 입력", style: .ghost) {
        model.backToEmail()
      }
    }
  }

  private var passwordStep: some View {
    VStack(spacing: 12) {
      field("이메일", text: $model.email, keyboard: .emailAddress)
      SecureField("비밀번호", text: $model.password)
        .textFieldStyle(.plain)
        .padding(14)
        .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      MutterButton("로그인", isLoading: model.isLoading, isEnabled: model.isEmailValid && !model.password.isEmpty) {
        Task { await model.signInWithPassword() }
      }
      MutterButton("코드로 로그인", style: .ghost) {
        model.backToEmail()
      }
    }
  }

  // MARK: - Social (Google/Kakao/Apple — 콘솔 키는 Sensitive.xcconfig에서 주입)
  // Mercury 패턴: provider별 버튼(SignInButtonView)을 allCases로 나열.

  private var socialSection: some View {
    VStack(spacing: 8) {
      Text("또는")
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
