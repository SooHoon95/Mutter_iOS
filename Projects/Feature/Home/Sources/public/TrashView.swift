import SwiftUI

import Domain
import UIComponent

/// 보낸 편지 삭제함 화면 — 지운 편지를 30일 동안 보관했다가 완전히 지운다. 행마다 복구 / 완전히 삭제.
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
    MutterTrashScaffold(
      title: L10n.trashTitle,
      notice: L10n.trashNotice,
      errorMessage: model.errorMessage,
      isEmpty: model.items.isEmpty,
      isLoading: model.isLoading,
      showsRestoredToast: model.showsRestoredToast,
      rowIDs: model.items.map(\.id),
      onBack: onBack,
      onRefresh: { await model.load() }
    ) {
      ForEach(model.items) { item in
        MutterTrashRow(
          title: item.title,
          details: [MutterTrashRow.remainingText(days: item.remainingDays())],
          onRestore: { Task { await model.restore(item) } },
          onPurge: { purgeTarget = item }
        )
      }
    }
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
}
