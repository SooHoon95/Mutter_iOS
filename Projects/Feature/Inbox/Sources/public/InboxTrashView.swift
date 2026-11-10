import SwiftUI

import Domain
import UIComponent

/// 받은 편지 삭제함 화면 — 받은 편지함에서 지운 편지를 30일 동안 보관한다. 행마다 복구 / 완전히 삭제.
/// 받은 편지함에서만 들어오므로 Inbox 피처 안에 둔다(Feature→Feature 의존 없이 FeatureRoute.inboxTrash로 push).
/// 완전히 삭제해도 받은 편지함에서만 지워진다 — 보낸 사람 편지는 남고, 링크를 다시 열면 다시 담긴다.
public struct InboxTrashView: View {
  @State private var model: InboxTrashModelData
  /// 완전 삭제 확인 대상 — non-nil이면 확인 다이얼로그를 띄운다.
  @State private var purgeTarget: DeletedInboxItem?
  private let onBack: () -> Void

  public init(inboxUsecase: InboxUsecasable, onBack: @escaping () -> Void) {
    _model = State(initialValue: InboxTrashModelData(inboxUsecase: inboxUsecase))
    self.onBack = onBack
  }

  public var body: some View {
    MutterTrashScaffold(
      title: L10n.inboxTrashTitle,
      notice: L10n.inboxTrashNotice,
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
          details: [
            L10n.inboxTrashSender(item.senderNickname ?? L10n.inboxTrashUnknownSender),
            MutterTrashRow.remainingText(days: item.remainingDays()),
          ],
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
      Text(L10n.inboxTrashPurgeConfirmDetail)
    }
  }
}
