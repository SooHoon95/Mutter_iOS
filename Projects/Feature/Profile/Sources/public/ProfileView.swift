import SwiftUI

import Domain
import UIComponent

/// 프로필 탭 — 닉네임 수정, 로그아웃, 계정 삭제.
public struct ProfileView: View {
  @State private var model: ProfileModelData
  @State private var showDeleteConfirm = false

  public init(
    profileUsecase: ProfileUsecasable,
    authUsecase: AuthUsecasable,
    onSignedOut: @escaping () -> Void
  ) {
    _model = State(initialValue: ProfileModelData(
      profileUsecase: profileUsecase,
      authUsecase: authUsecase,
      onSignedOut: onSignedOut
    ))
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("프로필")
            .fonts(.titleLarge)
            .foregroundStyle(Asset.Colors.ink.color)

          VStack(alignment: .leading, spacing: 8) {
            Text("닉네임").fonts(.captionBold).foregroundStyle(Asset.Colors.inkSoft.color)
            TextField("닉네임", text: $model.nickname)
              .textFieldStyle(.plain)
              .padding(14)
              .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
            MutterButton("저장", isLoading: model.isLoading, isEnabled: !model.nickname.isEmpty) {
              Task { await model.saveNickname() }
            }
          }

          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
          }

          Divider().background(Asset.Colors.inkFaint.color.opacity(0.2))

          VStack(spacing: 12) {
            MutterButton("로그아웃", style: .secondary) {
              Task { await model.signOut() }
            }
            MutterButton("계정 삭제", style: .ghost) {
              showDeleteConfirm = true
            }
          }
        }
        .padding(24)
        .frame(maxWidth: 480)
      }
    }
    .task { await model.load() }
    .toastIfNeeded($model.savedToast, text: "저장했어요")
    .confirmationDialog("계정을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
      Button("삭제", role: .destructive) { Task { await model.deleteAccount() } }
      Button("취소", role: .cancel) {}
    } message: {
      Text("편지와 연결이 모두 사라지며 되돌릴 수 없어요.")
    }
  }
}

private extension View {
  /// 저장 완료 토스트(간단 표시 — 전역 MutterToast 대신 로컬).
  @ViewBuilder
  func toastIfNeeded(_ flag: Binding<Bool>, text: String) -> some View {
    overlay(alignment: .bottom) {
      if flag.wrappedValue {
        Text(text)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ivory.color)
          .padding(.horizontal, 16).padding(.vertical, 12)
          .background(Asset.Colors.ink.color, in: Capsule())
          .padding(.bottom, 24)
          .task {
            try? await Task.sleep(for: .seconds(1.5))
            flag.wrappedValue = false
          }
      }
    }
  }
}
