import SwiftUI

import Domain
import UIComponent

/// 받은함 탭 — 보관한 편지 목록. 탭하면 수신 화면으로 연다.
public struct InboxView: View {
  @State private var model: InboxModelData
  private let onOpen: (String) -> Void

  public init(inboxUsecase: InboxUsecasable, onOpen: @escaping (String) -> Void) {
    _model = State(initialValue: InboxModelData(inboxUsecase: inboxUsecase))
    self.onOpen = onOpen
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        // MARK: 헤더
        HStack {
          Text("받은 편지함")
            .fonts(.titleLarge)
            .foregroundStyle(Asset.Colors.ink.color)
          Spacer()
          Button { } label: {
            MutterIcon(Asset.Images.settings, size: 22)
              .foregroundStyle(Asset.Colors.gold.color)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)

        // MARK: 목록 / 빈 상태
        if model.items.isEmpty && !model.isLoading {
          emptyState
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView {
            LazyVStack(spacing: 10) {
              ForEach(model.items) { item in
                Button { onOpen(item.token) } label: { letterCard(item) }
                  .buttonStyle(PressableButtonStyle())
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: 600)
          }
        }
      }
    }
    .task { await model.load() }
  }

  // MARK: - 편지 카드 (HomeView letterCard 스타일 미러)

  private func letterCard(_ item: InboxItem) -> some View {
    HStack(spacing: 12) {
      // 봉투 아이콘 — 열람 여부 필드 없으므로 항상 envelope(미열람 강조 스타일)
      ZStack {
        Circle()
          .fill(Asset.Colors.goldSoft.color)
          .frame(width: 40, height: 40)
        MutterIcon(Asset.Images.envelope, size: 20)
          .foregroundStyle(Asset.Colors.gold.color)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title.isEmpty ? "제목 없는 편지" : item.title)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        Text(Self.dateText(item.savedAt))
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      }

      Spacer()

      // 미열람 골드 점 배지 (열람 상태 필드 없으므로 항상 표시)
      Circle()
        .fill(Asset.Colors.gold.color)
        .frame(width: 8, height: 8)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.card)
    .contentShape(Rectangle())
  }

  // MARK: - 빈 상태

  private var emptyState: some View {
    VStack(spacing: 12) {
      MutterIcon(Asset.Images.emptyReceived, size: 120)
        .foregroundStyle(Asset.Colors.inkFaint.color)
      Text("받은 편지가 없어요")
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
