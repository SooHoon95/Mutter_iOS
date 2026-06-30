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

      if model.items.isEmpty && !model.isLoading {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(model.items) { item in
              Button { onOpen(item.token) } label: { row(item) }
                .buttonStyle(PressableButtonStyle())
            }
          }
          .padding(20)
          .frame(maxWidth: 600)
        }
      }
    }
    .task { await model.load() }
  }

  private func row(_ item: InboxItem) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "envelope.fill").foregroundStyle(Asset.Colors.gold.color)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title.isEmpty ? "제목 없는 편지" : item.title)
          .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
        Text(Self.dateText(item.savedAt))
          .fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(Asset.Colors.inkFaint.color)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.soft)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(Asset.Colors.inkFaint.color)
      Text("받은 편지가 없어요").fonts(.bodyLarge).foregroundStyle(Asset.Colors.inkSoft.color)
    }
  }

  private static func dateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
  }
}
