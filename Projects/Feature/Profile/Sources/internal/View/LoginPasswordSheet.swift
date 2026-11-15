import SwiftUI

import UIComponent

/// 프로필 → 로그인 비밀번호 설정·변경 시트. 새 비밀번호와 확인을 받아 저장한다.
struct LoginPasswordSheet: View {
  let model: ProfileModelData
  @Binding var isPresented: Bool

  @State private var password = ""
  @State private var confirm = ""

  var body: some View {
    VStack(spacing: 12) {
      Text(L10n.profileLoginPassword)
        .fonts(.bodyLargeBold)
        .foregroundStyle(Asset.Colors.ink.color)
        .padding(.bottom, 4)

      secureField(L10n.authSetPasswordNew, text: $password)
      secureField(L10n.authSetPasswordConfirm, text: $confirm)

      if let message = model.passwordErrorMessage {
        Text(message)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.danger.color)
          .multilineTextAlignment(.center)
      }

      MutterButton(
        L10n.profileLoginPasswordSave,
        isLoading: model.isSavingPassword,
        isEnabled: !password.isEmpty && !confirm.isEmpty
      ) {
        Task {
          if await model.saveLoginPassword(password, confirm: confirm) {
            isPresented = false
          }
        }
      }

      MutterButton(L10n.commonCancel, style: .ghost) {
        isPresented = false
      }
      .disabled(model.isSavingPassword)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Asset.Colors.surface.color.ignoresSafeArea())
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
    SecureField(placeholder, text: text)
      .textFieldStyle(.plain)
      .textContentType(.newPassword)
      .padding(14)
      .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }
}
