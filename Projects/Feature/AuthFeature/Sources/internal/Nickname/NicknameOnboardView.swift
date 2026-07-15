import SwiftUI

import Domain
import UIComponent

/// 닉네임 온보딩 화면(가입 직후). pre-app 루트 단계라 navbar/뒤로가기 없음(push 안 됨, 되돌아갈 곳 없음).
struct NicknameOnboardView: View {
  @State private var model: NicknameModelData

  init(profileUsecase: ProfileUsecasable, onComplete: @escaping () -> Void) {
    _model = State(initialValue: NicknameModelData(profileUsecase: profileUsecase, onComplete: onComplete))
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 20) {
        Spacer()
        VStack(spacing: 8) {
          Text(L10n.nicknameTitle)
            .fonts(.titleLarge)
            .foregroundStyle(Asset.Colors.ink.color)
          Text(L10n.nicknameSubtitle)
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkSoft.color)
        }

        TextField(L10n.commonNickname, text: $model.nickname)
          .textFieldStyle(.plain)
          .padding(14)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))

        if let message = model.errorMessage {
          Text(message)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.goldDeep.color)
        }

        MutterButton(L10n.nicknameStart, isLoading: model.isLoading, isEnabled: model.isValid) {
          Task { await model.save() }
        }

        Spacer()
        Spacer()
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: 420)
    }
  }
}
