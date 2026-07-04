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

  public init(
    letterUsecase: LetterUsecasable,
    receiptUsecase: ReceiptUsecasable
  ) {
    self.model = HomeModelData(letterUsecase: letterUsecase, receiptUsecase: receiptUsecase)
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
        MutterButton("새 편지 쓰기", icon: Asset.Images.compose) {
          coordinator.push(.compose(.new))
        }

        // 세그먼트 — 임시저장을 보낸 편지와 분리(통계·목록 혼입 방지).
        Picker("", selection: $selectedTab) {
          Text("보낸 편지").tag(HomeTab.sent)
          Text("임시저장").tag(HomeTab.draft)
        }
        .pickerStyle(.segmented)

        if displayRows.isEmpty && !model.isLoading {
          emptyState(for: selectedTab)
          Spacer()
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
                    Task { await model.delete(row.letter.id) }
                  } label: {
                    Label("삭제", systemImage: "trash")
                  }
                }
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(Asset.Colors.danger.color)
        }
      }
      .padding(20)
      .frame(maxWidth: 600)
    }
    .task { await model.load() }
  }

  // MARK: - 골드 통계 카드

  private var statCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("보낸 편지").fonts(.caption).foregroundStyle(Asset.Colors.onGold.color.opacity(0.8))
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(model.sentCount)").fonts(.display).foregroundStyle(Asset.Colors.onGold.color)
        Text("통 · \(model.openedCount)통 읽음")
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
      // 보낸 편지 → 뷰어, 임시저장 → 이어쓰기(작성 화면). 탭 자체가 이어쓰기 진입점.
      if row.isSent {
        coordinator.push(.viewer(.myLetter(letterId: row.letter.id)))
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
          Text(row.letter.title.isEmpty ? "제목 없는 편지" : row.letter.title)
            .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
          Text(cardSubtitle(row))
            .fonts(.caption)
            .foregroundStyle(row.isSent && row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
        }
        Spacer()
        if row.isSent { readBadge(row.isOpened) } else { draftBadge }
      }
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .contentShape(Rectangle())
  }

  /// 카드 부제 — 보낸 편지는 열람 요약, 임시저장은 이어쓰기 안내.
  private func cardSubtitle(_ row: HomeModelData.LetterRow) -> String {
    if !row.isSent { return "작성 중 · 탭하면 이어쓰기" }
    return row.openSummary.map { "\($0.openCount)번 열림" } ?? "아직 열리지 않음"
  }

  /// 임시저장 배지.
  private var draftBadge: some View {
    Text("작성 중")
      .fonts(.caption)
      .foregroundStyle(Asset.Colors.inkSoft.color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Asset.Colors.warm100.color, in: Capsule())
  }

  private func readBadge(_ read: Bool) -> some View {
    HStack(spacing: 3) {
      if read { MutterIcon(Asset.Images.read, size: 11) }
      Text(read ? "읽음" : "안읽음").fonts(.caption)
    }
    .foregroundStyle(read ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(read ? Asset.Colors.goldSoft.color : Asset.Colors.warm100.color, in: Capsule())
  }

  private func emptyState(for tab: HomeTab) -> some View {
    VStack(spacing: 12) {
      Asset.Images.emptySent.image.resizable().scaledToFit().frame(height: 120)
      Text(tab == .sent ? "아직 보낸 편지가 없어요" : "임시저장한 편지가 없어요")
        .fonts(.bodyLarge).foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }
}
