import SwiftUI

/// 삭제함 화면 골격 — 내비바·안내 문구·에러·빈 상태·목록·"되살렸어요" 토스트.
/// 보낸 편지 삭제함(Home)과 받은 편지 삭제함(Inbox)이 같은 레이아웃을 쓰고, 행(`MutterTrashRow`)과 동작만 다르다.
/// Feature끼리는 서로 모르므로 공통 골격을 UIComponent에 두고 데이터는 표시 값으로만 받는다.
public struct MutterTrashScaffold<Rows: View>: View {
  private let title: String
  private let notice: String
  private let errorMessage: String?
  private let isEmpty: Bool
  private let isLoading: Bool
  private let showsRestoredToast: Bool
  /// 목록 변화 애니메이션 기준(행 id 목록).
  private let rowIDs: [String]
  private let onBack: () -> Void
  private let onRefresh: () async -> Void
  private let rows: Rows

  public init(
    title: String,
    notice: String,
    errorMessage: String?,
    isEmpty: Bool,
    isLoading: Bool,
    showsRestoredToast: Bool,
    rowIDs: [String],
    onBack: @escaping () -> Void,
    onRefresh: @escaping () async -> Void,
    @ViewBuilder rows: () -> Rows
  ) {
    self.title = title
    self.notice = notice
    self.errorMessage = errorMessage
    self.isEmpty = isEmpty
    self.isLoading = isLoading
    self.showsRestoredToast = showsRestoredToast
    self.rowIDs = rowIDs
    self.onBack = onBack
    self.onRefresh = onRefresh
    self.rows = rows()
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          title,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        VStack(alignment: .leading, spacing: 14) {
          Text(notice)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkSoft.color)
            .padding(.horizontal, 20)

          if let errorMessage {
            Text(errorMessage)
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.danger.color)
              .padding(.horizontal, 20)
          }

          if isEmpty && !isLoading {
            ScrollView {
              emptyState
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
            }
            .refreshable { await onRefresh() }
          } else {
            List {
              rows
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(.default, value: rowIDs)
            .refreshable { await onRefresh() }
          }
        }
        .padding(.top, 8)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .overlay(alignment: .bottom) {
      if showsRestoredToast {
        MutterActionToast(L10n.trashRestored)
      }
    }
    .animation(.snappy, value: showsRestoredToast)
  }

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
