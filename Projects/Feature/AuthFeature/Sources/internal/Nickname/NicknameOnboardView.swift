import SwiftUI

import Domain
import UIComponent

/// 닉네임 온보딩 화면(가입 직후).
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
          Text("어떻게 불러드릴까요?")
            .fonts(.titleLarge)
            .foregroundStyle(Asset.Colors.ink.color)
          Text("받는 사람에게 보일 이름이에요")
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkSoft.color)
        }

        TextField("닉네임", text: $model.nickname)
          .textFieldStyle(.plain)
          .padding(14)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))

        if let message = model.errorMessage {
          Text(message)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.goldDeep.color)
        }

        MutterButton("시작하기", isLoading: model.isLoading, isEnabled: model.isValid) {
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
