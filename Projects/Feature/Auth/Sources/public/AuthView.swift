import SwiftUI

import Domain
import UIComponent

/// 로그인 화면 — 이메일 매직코드(가입 겸용) + 비밀번호. 수신 무마찰 원칙상 가볍게.
public struct AuthView: View {
  @State private var model: AuthModelData

  public init(authUsecase: AuthUsecasable, onAuthenticated: @escaping () -> Void) {
    _model = State(initialValue: AuthModelData(authUsecase: authUsecase, onAuthenticated: onAuthenticated))
  }

  public var body: some View {
    ZStack {
      MutterColor.ivory.ignoresSafeArea()

      VStack(spacing: 24) {
        Spacer()

        VStack(spacing: 8) {
          Text("Mutter")
            .fonts(.display)
            .foregroundStyle(MutterColor.ink)
          Text("연출되는 편지")
            .fonts(.bodyMedium)
            .foregroundStyle(MutterColor.inkSoft)
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
              .foregroundStyle(MutterColor.goldDeep)
              .multilineTextAlignment(.center)
          }
        }
        .padding(20)
        .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
        .shadows(.soft)

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
        .foregroundStyle(MutterColor.inkSoft)
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
        .background(MutterColor.ivory, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      MutterButton("로그인", isLoading: model.isLoading, isEnabled: model.isEmailValid && !model.password.isEmpty) {
        Task { await model.signInWithPassword() }
      }
      MutterButton("코드로 로그인", style: .ghost) {
        model.backToEmail()
      }
    }
  }

  // MARK: - Social (SDK·콘솔 설정 보류 — Phase2 후반)

  private var socialSection: some View {
    VStack(spacing: 8) {
      Text("또는")
        .fonts(.caption)
        .foregroundStyle(MutterColor.inkFaint)
      HStack(spacing: 12) {
        socialButton("Apple로 계속")
        socialButton("Google로 계속")
      }
    }
  }

  private func socialButton(_ title: String) -> some View {
    Button {
      model.errorMessage = "소셜 로그인은 준비 중이에요."
    } label: {
      Text(title)
        .fonts(.captionBold)
        .foregroundStyle(MutterColor.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        .overlay(
          RoundedRectangle(cornerRadius: MutterRadius.md)
            .stroke(MutterColor.inkFaint.opacity(0.3), lineWidth: 1)
        )
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
      .background(MutterColor.ivory, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }
}
