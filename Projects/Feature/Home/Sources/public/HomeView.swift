import SwiftUI

import Domain
import UIComponent
import Router


/// 홈(우체통) 탭 — 골드 통계카드 + 새 편지 쓰기 + 최근 보낸 편지(읽음 배지). 디자인 시스템 반영.
public struct HomeView: View {
  /// 홈 세그먼트 — 보낸 편지(전달됨) vs 임시저장(작성 중).
  private enum HomeTab: Hashable { case sent, draft }

  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  @State private var model: HomeModelData
  @State private var selectedTab: HomeTab = .sent
  /// 받은 사람이 간직한 편지를 지우려 할 때 확인을 기다리는 편지 id.
  @State private var keptDeleteLetterId: String?

  public init(
    letterUsecase: LetterUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable
  ) {
    self.model = HomeModelData(
      letterUsecase: letterUsecase,
      receiptUsecase: receiptUsecase,
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase
    )
  }

  /// 현재 탭에 보여줄 행.
  private var displayRows: [HomeModelData.LetterRow] {
    selectedTab == .sent ? model.sentRows : model.draftRows
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 18) {
        statCard
        MutterButton(L10n.homeCompose, icon: Asset.Images.compose) {
          coordinator.push(.compose(.new))
        }

        // 세그먼트 — 임시저장을 보낸 편지와 분리(통계·목록 혼입 방지). 옆에 삭제함 진입점.
        HStack(spacing: 12) {
          Picker("", selection: $selectedTab) {
            Text(L10n.homeTabSent).tag(HomeTab.sent)
            Text(L10n.homeTabDraft).tag(HomeTab.draft)
          }
          .pickerStyle(.segmented)
          trashButton
        }

        if displayRows.isEmpty && !model.isLoading {
          ScrollView {
            emptyState(for: selectedTab)
              .frame(maxWidth: .infinity)
              .containerRelativeFrame(.vertical)
          }
          .refreshable { await model.load() }
        } else {
          List {
            ForEach(displayRows) { row in
              letterCard(row)
                .shadows(.shadowMediumLow)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button(role: .destructive) {
                    // 받은 사람이 편지권으로 간직한 편지만 한 번 묻는다. 나머지는 지금처럼 바로 지우고 되돌리기.
                    if model.isKeptByRecipient(row.letter.id) {
                      keptDeleteLetterId = row.letter.id
                    } else {
                      Task { await model.delete(row.letter.id) }
                    }
                  } label: {
                    Label(L10n.commonDelete, systemImage: "trash")
                  }
                }
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .refreshable { await model.load() }
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(Asset.Colors.danger.color)
        }
      }
      .padding(20)
      .frame(maxWidth: 600)
    }
    .overlay(alignment: .bottom) {
      if model.undoableLetterId != nil {
        MutterActionToast(L10n.homeMovedToTrash, actionTitle: L10n.commonUndo) {
          Task { await model.undoDelete() }
        }
      }
    }
    .animation(.snappy, value: model.undoableLetterId)
    .confirmationDialog(
      L10n.accessKeptDeleteWarning,
      isPresented: Binding(get: { keptDeleteLetterId != nil }, set: { if !$0 { keptDeleteLetterId = nil } }),
      titleVisibility: .visible
    ) {
      Button(L10n.commonDelete, role: .destructive) {
        guard let letterId = keptDeleteLetterId else { return }
        keptDeleteLetterId = nil
        Task { await model.delete(letterId) }
      }
      Button(L10n.commonCancel, role: .cancel) { keptDeleteLetterId = nil }
    }
    // 삭제함에서 되살리고 돌아오면 다시 보여야 하므로 나타날 때마다 새로 받는다.
    .task { await model.load() }
  }

  // MARK: - 삭제함 진입

  private var trashButton: some View {
    Button {
      coordinator.push(.trash)
    } label: {
      Image(systemName: "trash")
        .font(.system(size: 17, weight: .regular))
        .foregroundStyle(Asset.Colors.inkSoft.color)
        .frame(width: 32, height: 32)
    }
    .accessibilityLabel(L10n.homeTrash)
  }

  // MARK: - 골드 통계 카드

  private var statCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(L10n.homeSentCount).fonts(.caption).foregroundStyle(Asset.Colors.onGold.color.opacity(0.8))
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(model.sentCount)").fonts(.display).foregroundStyle(Asset.Colors.onGold.color)
        Text(L10n.homeSentUnit(model.openedCount))
          .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.onGold.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20)
    .padding(.vertical, 18)
    .background(MutterGradient.gold, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }

  // MARK: - 편지 카드

  private func letterCard(_ row: HomeModelData.LetterRow) -> some View {
    Button {
      // 보낸 편지 → 링크 관리(발급된 링크 목록·무효화·새 발급, 미리보기는 그 안 버튼).
      // 임시저장 → 이어쓰기(작성 화면). 탭 자체가 이어쓰기 진입점.
      if row.isSent {
        coordinator.push(.delivery(letterId: row.letter.id))
      } else {
        coordinator.push(.compose(.edit(letterId: row.letter.id)))
      }
    } label: {
      HStack(spacing: 12) {
        MutterIcon(
          row.isSent ? (row.isOpened ? Asset.Images.envelopeOpen : Asset.Images.envelope) : Asset.Images.compose,
          size: 22
        )
        .foregroundStyle(row.isSent && row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
        VStack(alignment: .leading, spacing: 4) {
          Text(row.letter.title.isEmpty ? L10n.commonUntitledLetter : row.letter.title)
            .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
          Text(cardSubtitle(row))
            .fonts(.caption)
            .foregroundStyle(row.isSent && row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
        }
        Spacer()
        // 접근 상태(영구·n일 남음·닫힘) — 상태가 없으면 아무것도 붙이지 않는다.
        if let badge = model.accessBadge(for: row) { badge.badge }
        if row.isSent { readBadge(row.isOpened) } else { draftBadge }
      }
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .contentShape(Rectangle())
  }

  /// 카드 부제 — 보낸 편지는 열람 요약, 임시저장은 이어쓰기 안내.
  private func cardSubtitle(_ row: HomeModelData.LetterRow) -> String {
    if !row.isSent { return L10n.homeDraftInProgress }
    return row.openSummary.map { L10n.homeOpened($0.openCount) } ?? L10n.homeNotOpened
  }

  /// 임시저장 배지.
  private var draftBadge: some View {
    Text(L10n.homeWriting)
      .fonts(.caption)
      .foregroundStyle(Asset.Colors.inkSoft.color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Asset.Colors.warm100.color, in: Capsule())
  }

  private func readBadge(_ read: Bool) -> some View {
    HStack(spacing: 3) {
      if read { MutterIcon(Asset.Images.read, size: 11) }
      Text(read ? L10n.homeRead : L10n.homeUnread).fonts(.caption)
    }
    .foregroundStyle(read ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(read ? Asset.Colors.goldSoft.color : Asset.Colors.warm100.color, in: Capsule())
  }

  private func emptyState(for tab: HomeTab) -> some View {
    VStack(spacing: 12) {
      Asset.Images.emptySent.image.resizable().scaledToFit().frame(height: 120)
      Text(tab == .sent ? L10n.homeEmptySent : L10n.homeEmptyDraft)
        .fonts(.bodyLarge).foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }
}
