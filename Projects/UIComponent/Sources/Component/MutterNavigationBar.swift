import SwiftUI

/// Mutter 상단 네비게이션 바(Mercury `MercuryNavigationBar` 패턴).
/// 제목 + 좌/우 버튼 슬롯(@ViewBuilder). 제목은 명조 계열.
public struct MutterNavigationBar<LeftContent: View, RightContent: View>: View {
  private let title: String?
  private let titleFont: MutterFont
  private let leftButtons: LeftContent
  private let rightButtons: RightContent

  public init(
    _ title: String? = nil,
    titleFont: MutterFont = .title,
    @ViewBuilder leftButtons: () -> LeftContent = { EmptyView() },
    @ViewBuilder rightButtons: () -> RightContent = { EmptyView() }
  ) {
    self.title = title
    self.titleFont = titleFont
    self.leftButtons = leftButtons()
    self.rightButtons = rightButtons()
  }

  public var body: some View {
    ZStack {
      if let title {
        Text(title)
          .fonts(titleFont)
          .foregroundStyle(MutterColor.ink)
          .lineLimit(1)
      }

      HStack(spacing: 0) {
        leftButtons
          .frame(minWidth: 28, minHeight: 28)
        Spacer(minLength: 0)
        rightButtons
          .frame(minWidth: 28, minHeight: 28)
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .background(MutterColor.surface)
  }
}
