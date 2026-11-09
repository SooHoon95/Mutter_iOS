import SwiftUI

import Domain
import UIComponent

/// 삭제함 화면 — 지운 편지를 30일 동안 보관했다가 완전히 지운다. 행마다 복구 / 완전히 삭제.
/// 홈(내 편지)에서만 들어오므로 Home 피처 안에 둔다(Feature→Feature 의존 없이 FeatureRoute.trash로 push).
public struct TrashView: View {
  @State private var model: TrashModelData
  /// 완전 삭제 확인 대상 — non-nil이면 확인 다이얼로그를 띄운다.
  @State private var purgeTarget: DeletedLetter?
  private let onBack: () -> Void

  public init(letterUsecase: LetterUsecasable, onBack: @escaping () -> Void) {
    _model = State(initialValue: TrashModelData(letterUsecase: letterUsecase))
    self.onBack = onBack
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          L10n.trashTitle,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        VStack(alignment: .leading, spacing: 14) {
          Text(L10n.trashNotice)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkSoft.color)
            .padding(.horizontal, 20)

          if let message = model.errorMessage {
            Text(message)
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.danger.color)
              .padding(.horizontal, 20)
          }

          if model.items.isEmpty && !model.isLoading {
            ScrollView {
              emptyState
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
            }
            .refreshable { await model.load() }
          } else {
            List {
              ForEach(model.items) { item in
                row(item)
                  .frame(maxWidth: 600)
                  .frame(maxWidth: .infinity)
                  .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                  .listRowSeparator(.hidden)
                  .listRowBackground(Color.clear)
              }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(.default, value: model.items)
            .refreshable { await model.load() }
          }
        }
        .padding(.top, 8)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .overlay(alignment: .bottom) {
      if model.showsRestoredToast {
        MutterActionToast(L10n.trashRestored)
      }
    }
    .animation(.snappy, value: model.showsRestoredToast)
    .task { await model.load() }
    .confirmationDialog(
      L10n.trashPurgeConfirm,
      isPresented: Binding(get: { purgeTarget != nil }, set: { if !$0 { purgeTarget = nil } }),
      titleVisibility: .visible,
      presenting: purgeTarget
    ) { target in
      Button(L10n.trashPurge, role: .destructive) { Task { await model.purge(target) } }
      Button(L10n.commonCancel, role: .cancel) {}
    } message: { _ in
      Text(L10n.trashPurgeConfirmDetail)
    }
  }

  // MARK: - 행

  private func row(_ item: DeletedLetter) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title.isEmpty ? L10n.trashUntitled : item.title)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        Text(Self.remainingText(item))
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkFaint.color)
      }
      Spacer(minLength: 0)
      actionButton(L10n.trashRestore, foreground: Asset.Colors.gold.color, background: Asset.Colors.goldSoft.color) {
        Task { await model.restore(item) }
      }
      actionButton(L10n.trashPurge, foreground: Asset.Colors.danger.color, background: Asset.Colors.warm100.color) {
        purgeTarget = item
      }
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.shadowMediumLow)
  }

  /// 행 안의 작은 캡슐 버튼. List 행 안에서 버튼마다 따로 눌리도록 `.plain` 스타일을 쓴다
  /// (기본 스타일이면 행 전체가 한 버튼처럼 탭돼 두 동작이 함께 실행된다).
  private func actionButton(
    _ title: String,
    foreground: Color,
    background: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .fonts(.captionBold)
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(background, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  /// "N일 후 완전히 삭제" / 기한이 지났거나 오늘이면 "오늘 완전히 삭제".
  private static func remainingText(_ item: DeletedLetter) -> String {
    let days = item.remainingDays()
    return days > 0 ? L10n.trashDaysLeft(days) : L10n.trashPurgeToday
  }

  // MARK: - 빈 상태

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "trash")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(Asset.Colors.inkFaint.color)
      Text(L10n.trashEmpty)
        .fonts(.bodyLarge)
        .foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .padding(.top, 40)
  }
}
