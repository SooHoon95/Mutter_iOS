import SwiftUI

import Domain
import UIComponent

/// 홈(우체통) 탭 — 골드 통계카드 + 새 편지 쓰기 + 최근 보낸 편지(읽음 배지). 디자인 시스템 반영.
public struct HomeView: View {
  @State private var model: HomeModelData
  private let onCompose: () -> Void
  private let onEdit: (String) -> Void
  private let onPreview: (String) -> Void

  public init(
    letterUsecase: LetterUsecasable,
    receiptUsecase: ReceiptUsecasable,
    onCompose: @escaping () -> Void,
    onEdit: @escaping (String) -> Void,
    onPreview: @escaping (String) -> Void
  ) {
    _model = State(initialValue: HomeModelData(letterUsecase: letterUsecase, receiptUsecase: receiptUsecase))
    self.onCompose = onCompose
    self.onEdit = onEdit
    self.onPreview = onPreview
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 18) {
        statCard
        MutterButton("새 편지 쓰기", icon: Asset.Images.compose) { onCompose() }

        if model.rows.isEmpty && !model.isLoading {
          emptyState
          Spacer()
        } else {
          sectionLabel("최근 보낸 편지")
          List {
            ForEach(model.rows) { row in
              letterCard(row)
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
                .swipeActions(edge: .leading) {
                  Button { onEdit(row.letter.id) } label: {
                    Label("이어쓰기", systemImage: "pencil")
                  }
                  .tint(Asset.Colors.gold.color)
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
    .shadows(.gold)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .fonts(.captionBold)
      .foregroundStyle(Asset.Colors.inkFaint.color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - 편지 카드

  private func letterCard(_ row: HomeModelData.LetterRow) -> some View {
    HStack(spacing: 12) {
      MutterIcon(row.isOpened ? Asset.Images.envelopeOpen : Asset.Images.envelope, size: 22)
        .foregroundStyle(row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
      VStack(alignment: .leading, spacing: 4) {
        Text(row.letter.title.isEmpty ? "제목 없는 편지" : row.letter.title)
          .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
        Text(row.openSummary.map { "\($0.openCount)번 열림" } ?? "아직 열리지 않음")
          .fonts(.caption)
          .foregroundStyle(row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
      }
      Spacer()
      readBadge(row.isOpened)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.soft)
    .contentShape(Rectangle())
    .onTapGesture { onPreview(row.letter.id) }
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

  private var emptyState: some View {
    VStack(spacing: 12) {
      Asset.Images.emptySent.image.resizable().scaledToFit().frame(height: 120)
      Text("아직 보낸 편지가 없어요").fonts(.bodyLarge).foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }
}
