import SwiftUI
import UIKit

import Domain
import UIComponent

/// 프로필 탭 — 닉네임 수정, 로그아웃, 계정 삭제.
public struct ProfileView: View {
  @State private var model: ProfileModelData
  @State private var showDeleteConfirm = false
  @State private var isEditingNickname = false
  @State private var mailFallbackToast = false
  @FocusState private var nicknameFocused: Bool
  @Environment(\.openURL) private var openURL

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
        VStack(spacing: 32) {
          avatarHeader
          settingsCard
          actionButtons
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(maxWidth: 480)
      }
    }
    .task { await model.load() }
    .toastIfNeeded($model.savedToast, text: "저장했어요")
    .toastIfNeeded($mailFallbackToast, text: "메일 앱이 없어 이메일 주소를 복사했어요")
    .confirmationDialog("계정을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
      Button("삭제", role: .destructive) { Task { await model.deleteAccount() } }
      Button("취소", role: .cancel) {}
    } message: {
      Text("편지와 연결이 모두 사라지며 되돌릴 수 없어요. 상대가 보관한 편지도 함께 사라집니다.")
    }
  }

  // MARK: - 아바타 헤더

  private var avatarHeader: some View {
    VStack(spacing: 12) {
      // 아바타 원형 — 닉네임 첫 글자
      ZStack {
        Circle()
          .fill(Asset.Colors.goldSoft.color)
          .frame(width: 72, height: 72)
        Text(model.nickname.first.map(String.init) ?? "M")
          .fonts(.titleLarge)
          .foregroundStyle(Asset.Colors.goldDeep.color)
      }

      // 닉네임
      Text(model.nickname.isEmpty ? "닉네임" : model.nickname)
        .fonts(.display)
        .foregroundStyle(Asset.Colors.ink.color)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - 설정 카드

  private var settingsCard: some View {
    VStack(spacing: 0) {
      // 닉네임 행 — 탭하면 인라인 편집 모드 진입
      if isEditingNickname {
        nicknameEditRow
      } else {
        settingsRow(
          icon: Asset.Images.person,
          label: "닉네임",
          value: model.nickname.isEmpty ? "—" : model.nickname
        ) {
          isEditingNickname = true
          nicknameFocused = true
        }
      }

      hairlineDivider

      settingsRow(
        icon: Asset.Images.moodTag,
        label: "기본 편지지",
        value: "봄날",
        action: nil
      )

      hairlineDivider

      settingsRow(
        icon: Asset.Images.lock,
        label: "암호 기본값",
        value: "켜짐",
        action: nil
      )
    }
    .background(Asset.Colors.surface.color)
    .clipShape(RoundedRectangle(cornerRadius: MutterRadius.xl))
    .overlay(
      RoundedRectangle(cornerRadius: MutterRadius.xl)
        .strokeBorder(Asset.Colors.hairline.color, lineWidth: 0.5)
    )
    .shadows(.shadowLow)
  }

  // MARK: - 닉네임 인라인 편집 행

  private var nicknameEditRow: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        MutterIcon(Asset.Images.person, size: 20)
          .foregroundStyle(Asset.Colors.inkSoft.color)

        TextField("닉네임", text: $model.nickname)
          .textFieldStyle(.plain)
          .fonts(.bodyLarge)
          .foregroundStyle(Asset.Colors.ink.color)
          .focused($nicknameFocused)
          .submitLabel(.done)
          .onSubmit {
            Task {
              await model.saveNickname()
              isEditingNickname = false
              nicknameFocused = false
            }
          }

        if model.isLoading {
          ProgressView()
            .tint(Asset.Colors.gold.color)
        } else {
          Button {
            Task {
              await model.saveNickname()
              isEditingNickname = false
              nicknameFocused = false
            }
          } label: {
            MutterIcon(Asset.Images.check, size: 16)
              .foregroundStyle(Asset.Colors.gold.color)
          }
          .disabled(model.nickname.isEmpty || model.isLoading)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)

      if let message = model.errorMessage {
        Text(message)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.danger.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.bottom, 10)
      }
    }
  }

  // MARK: - 설정 행 (아이콘·레이블·값·chevron)

  private func settingsRow(
    icon: ImageAsset,
    label: String,
    value: String,
    action: (() -> Void)?
  ) -> some View {
    Button {
      action?()
    } label: {
      HStack(spacing: 12) {
        MutterIcon(icon, size: 20)
          .foregroundStyle(Asset.Colors.inkSoft.color)
        Text(label)
          .fonts(.bodyLarge)
          .foregroundStyle(Asset.Colors.ink.color)
        Spacer()
        Text(value)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.inkSoft.color)
        MutterIcon(Asset.Images.chevronRight, size: 16)
          .foregroundStyle(Asset.Colors.inkFaint.color)
          .opacity(action != nil ? 1 : 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .disabled(action == nil)
    .buttonStyle(.plain)
  }

  // MARK: - 구분선

  private var hairlineDivider: some View {
    Rectangle()
      .fill(Asset.Colors.hairline.color)
      .frame(height: 0.5)
      .padding(.leading, 48)
  }

  // MARK: - 액션 버튼

  private let contactEmail = "dkehskeh@gmail.com"

  /// 문의 메일 URL — 제목에 반드시 "Mutter" 포함(요구사항). mailto로 기본 메일 앱을 연다.
  private var contactMailURL: URL? {
    let subject = "[Mutter] 문의사항"
    let body = "문의 내용을 적어주세요.\n\n———\n(원활한 답변을 위해 앱 버전/기기 정보를 함께 남겨주시면 좋아요.)"
    let allowed = CharacterSet.alphanumerics
    let s = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    let b = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    return URL(string: "mailto:\(contactEmail)?subject=\(s)&body=\(b)")
  }

  private var actionButtons: some View {
    VStack(spacing: 8) {
      MutterButton("문의하기", style: .ghost) {
        guard let url = contactMailURL else { return }
        openURL(url) { accepted in
          if !accepted {
            // 메일 앱이 없거나 못 열면 이메일 주소를 복사해 문의 경로를 남긴다.
            UIPasteboard.general.string = contactEmail
            mailFallbackToast = true
          }
        }
      }

      MutterButton("로그아웃", style: .ghost) {
        Task { await model.signOut() }
      }

      Button {
        showDeleteConfirm = true
      } label: {
        Text("계정 삭제")
          .fonts(.bodyLargeBold)
          .foregroundStyle(Asset.Colors.danger.color)
          .frame(maxWidth: .infinity, minHeight: 54)
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - 저장 완료 토스트

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
