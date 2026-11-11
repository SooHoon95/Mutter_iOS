import SwiftUI

import Domain
import UIComponent

/// 받은함 탭 — 보관한 편지 목록. 탭하면 수신 화면으로 연다.
/// 헤더의 편집 버튼으로 여러 통을 골라 지우고, 삭제함 버튼으로 받은 편지 삭제함에 들어간다.
public struct InboxView: View {
  @State private var model: InboxModelData
  private let onOpen: (String) -> Void
  private let onOpenTrash: () -> Void

  public init(
    inboxUsecase: InboxUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable,
    onOpen: @escaping (String) -> Void,
    onOpenTrash: @escaping () -> Void
  ) {
    _model = State(initialValue: InboxModelData(
      inboxUsecase: inboxUsecase,
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase
    ))
    self.onOpen = onOpen
    self.onOpenTrash = onOpenTrash
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        header

        if let message = model.errorMessage {
          Text(message)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.danger.color)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }

        // MARK: 목록 / 빈 상태
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
              Button {
                if model.isEditing { model.toggleSelection(item) } else { onOpen(item.token) }
              } label: {
                letterCard(item)
              }
                .buttonStyle(PressableButtonStyle())
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  // 편집 모드에선 액션을 비워 스와이프를 끈다(선택 탭과 제스처가 겹치지 않게).
                  if !model.isEditing {
                    Button(role: .destructive) {
                      Task { await model.delete([item]) }
                    } label: {
                      Label(L10n.commonDelete, systemImage: "trash")
                    }
                  }
                }
            }
          }
          .listStyle(.plain)
          .listRowSpacing(10)
          .scrollContentBackground(.hidden)
          .contentMargins(.bottom, 20, for: .scrollContent)
          .animation(.default, value: model.items)
          // 편집 모드에선 새로고침을 건너뛴다(선택 중 목록이 바뀌지 않게). 수식어를 조건부로 붙였다 떼면
          // List 정체성이 바뀌어 편집 모드를 켜고 끌 때마다 스크롤이 맨 위로 돌아가므로 항상 붙여 둔다.
          .refreshable {
            guard !model.isEditing else { return }
            await model.load()
          }
        }

        if model.isEditing { editBar }
      }
    }
    .overlay(alignment: .bottom) {
      if !model.undoableLetterIds.isEmpty {
        MutterActionToast(model.undoToastMessage, actionTitle: L10n.commonUndo) {
          Task { await model.undoDelete() }
        }
      }
    }
    .animation(.snappy, value: model.undoableLetterIds)
    .animation(.snappy, value: model.isEditing)
    // 받은 편지 삭제함에서 복구하고 돌아오면 다시 보여야 하므로 나타날 때마다 새로 받는다.
    .task { await model.load() }
  }

  // MARK: - 헤더

  private var header: some View {
    HStack(spacing: 16) {
      Text(L10n.inboxTitle)
        .fonts(.titleLarge)
        .foregroundStyle(Asset.Colors.ink.color)
      Spacer()
      Button(action: onOpenTrash) {
        Image(systemName: "trash")
          .font(.system(size: 19, weight: .regular))
          .foregroundStyle(Asset.Colors.gold.color)
      }
      .accessibilityLabel(L10n.inboxTrashTitle)
      // 선택 중엔 화면을 떠나지 않게 막는다(Android·웹과 동일).
      .disabled(model.isEditing)
      .opacity(model.isEditing ? 0.35 : 1)
      Button { model.toggleEditing() } label: {
        Text(model.isEditing ? L10n.commonDone : L10n.inboxEdit)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.gold.color)
      }
      .disabled(model.items.isEmpty && !model.isEditing)
    }
    .padding(.horizontal, 20)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  // MARK: - 편집 모드 하단 바

  private var editBar: some View {
    HStack {
      Button { model.toggleSelectAll() } label: {
        Text(model.isAllSelected ? L10n.inboxDeselectAll : L10n.inboxSelectAll)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
      }
      Spacer()
      Button { Task { await model.deleteSelected() } } label: {
        Text(L10n.inboxDeleteSelected(model.selectedIds.count))
          .fonts(.bodyMediumBold)
          .foregroundStyle(model.selectedIds.isEmpty ? Asset.Colors.inkFaint.color : Asset.Colors.danger.color)
      }
      .disabled(model.selectedIds.isEmpty)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(Asset.Colors.surface.color)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  // MARK: - 편지 카드 (HomeView letterCard 스타일 미러)

  private func letterCard(_ item: InboxItem) -> some View {
    HStack(spacing: 12) {
      // 편집 모드 선택 원.
      if model.isEditing {
        let selected = model.selectedIds.contains(item.id)
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .regular))
          .foregroundStyle(selected ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
      }
      // 봉투 아이콘 — 열람 여부 필드 없으므로 항상 envelope(미열람 강조 스타일)
      ZStack {
        Circle()
          .fill(Asset.Colors.goldSoft.color)
          .frame(width: 40, height: 40)
        MutterIcon(Asset.Images.envelope, size: 20)
          .foregroundStyle(Asset.Colors.gold.color)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title.isEmpty ? L10n.commonUntitledLetter : item.title)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        Text(Self.dateText(item.savedAt))
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      }

      Spacer()

      // 접근 상태(영구·n일 남음·닫힘) — 상태가 없으면 아무것도 붙이지 않는다.
      if let badge = model.accessBadge(for: item) { badge.badge }

      // 미열람 골드 점 배지 (열람 상태 필드 없으므로 항상 표시)
      Circle()
        .fill(Asset.Colors.gold.color)
        .frame(width: 8, height: 8)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.shadowMediumLow)
    .contentShape(Rectangle())
  }

  // MARK: - 빈 상태

  private var emptyState: some View {
    VStack(spacing: 12) {
      MutterIcon(Asset.Images.emptyReceived, size: 120)
        .foregroundStyle(Asset.Colors.inkFaint.color)
      Text(L10n.inboxEmpty)
        .fonts(.bodyLarge)
        .foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .padding(.top, 60)
  }

  // MARK: - 날짜 포맷

  private static func dateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
  }
}
