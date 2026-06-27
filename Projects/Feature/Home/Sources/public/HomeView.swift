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
      MutterColor.ivory.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header
          MutterButton("새 편지 쓰기") { onCompose() }

          if model.rows.isEmpty && !model.isLoading {
            emptyState
          } else {
            LazyVStack(spacing: 10) {
              ForEach(model.rows) { row in
                letterCard(row)
              }
            }
          }
        }
        .padding(24)
        .frame(maxWidth: 600)
      }
    }
    .task { await model.load() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("우체통").fonts(.titleLarge).foregroundStyle(MutterColor.ink)
      Text("보낸 편지 \(model.sentCount)통 · 열어본 \(model.openedCount)통")
        .fonts(.bodyMedium).foregroundStyle(MutterColor.inkSoft)
    }
  }

  private func letterCard(_ row: HomeModelData.LetterRow) -> some View {
    HStack(spacing: 12) {
      Image(systemName: row.isOpened ? "envelope.open.fill" : "envelope.fill")
        .foregroundStyle(row.isOpened ? MutterColor.gold : MutterColor.inkFaint)
      VStack(alignment: .leading, spacing: 4) {
        Text(row.letter.title.isEmpty ? "제목 없는 편지" : row.letter.title)
          .fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink).lineLimit(1)
        if let summary = row.openSummary {
          Text("\(summary.openCount)번 열림").fonts(.caption).foregroundStyle(MutterColor.gold)
        } else {
          Text("아직 열리지 않음").fonts(.caption).foregroundStyle(MutterColor.inkFaint)
        }
      }
      Spacer()
      Button("이어쓰기") { onEdit(row.letter.id) }
        .fonts(.captionBold)
        .foregroundStyle(MutterColor.goldDeep)
    }
    .padding(16)
    .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.soft)
    .contentShape(Rectangle())
    .onTapGesture { onPreview(row.letter.id) }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "paperplane").font(.system(size: 32)).foregroundStyle(MutterColor.inkFaint)
      Text("아직 보낸 편지가 없어요").fonts(.bodyLarge).foregroundStyle(MutterColor.inkSoft)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }
}
