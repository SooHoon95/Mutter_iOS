import SwiftUI

import Domain
import UIComponent

/// 홈(우체통) 탭 — 보낸 편지 수 비주얼 + 읽음 상태 + 새 편지/이어쓰기.
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
      VStack(alignment: .leading, spacing: 20) {
        header
        MutterButton("새 편지 쓰기") { onCompose() }

        if model.rows.isEmpty && !model.isLoading {
          emptyState
          Spacer()
        } else {
          // 스와이프 삭제 — 네이티브 .swipeActions는 List가 필요해 카드 목록을 List로.
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
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
        }
      }
      .padding(24)
      .frame(maxWidth: 600)
    }
    .task { await model.load() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("우체통").fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)
      Text("보낸 편지 \(model.sentCount)통 · 열어본 \(model.openedCount)통")
        .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)
    }
  }

  private func letterCard(_ row: HomeModelData.LetterRow) -> some View {
    HStack(spacing: 12) {
      Image(systemName: row.isOpened ? "envelope.open.fill" : "envelope.fill")
        .foregroundStyle(row.isOpened ? Asset.Colors.gold.color : Asset.Colors.inkFaint.color)
      VStack(alignment: .leading, spacing: 4) {
        Text(row.letter.title.isEmpty ? "제목 없는 편지" : row.letter.title)
          .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
        if let summary = row.openSummary {
          Text("\(summary.openCount)번 열림").fonts(.caption).foregroundStyle(Asset.Colors.gold.color)
        } else {
          Text("아직 열리지 않음").fonts(.caption).foregroundStyle(Asset.Colors.inkFaint.color)
        }
      }
      Spacer()
      Button("이어쓰기") { onEdit(row.letter.id) }
        .fonts(.captionBold)
        .foregroundStyle(Asset.Colors.goldDeep.color)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.soft)
    .contentShape(Rectangle())
    .onTapGesture { onPreview(row.letter.id) }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "paperplane").font(.system(size: 32)).foregroundStyle(Asset.Colors.inkFaint.color)
      Text("아직 보낸 편지가 없어요").fonts(.bodyLarge).foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }
}
