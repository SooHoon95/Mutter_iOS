import SwiftUI

/// Mutter 상단 네비게이션 바(Mercury `MercuryNavigationBar` 패턴).
/// 제목 + 좌/우 버튼 슬롯(@ViewBuilder). 제목은 명조 계열.
public struct MutterNavigationBar<LeftContent: View, RightContent: View>: View {
  private let backgroundColor: Color?
  private let title: String?
  private let titleFont: MutterFont
  /// 타이틀·버튼 아이콘 색. 편지 테마와 정합할 때 배경에 맞춰 주입(MU-7). 기본은 ink.
  private let foregroundColor: Color
  private let leftButtons: LeftContent
  private let rightButtons: RightContent

  public init(
    _ backgroundColor: Color? = Asset.Colors.ivory.color,
    _ title: String? = nil,
    titleFont: MutterFont = .title,
    foregroundColor: Color = Asset.Colors.ink.color,
    @ViewBuilder leftButtons: () -> LeftContent = { EmptyView() },
    @ViewBuilder rightButtons: () -> RightContent = { EmptyView() }
  ) {
    self.backgroundColor = backgroundColor
    self.title = title
    self.titleFont = titleFont
    self.foregroundColor = foregroundColor
    self.leftButtons = leftButtons()
    self.rightButtons = rightButtons()
  }

  public var body: some View {
    ZStack {
      backgroundColor
      if let title {
        Text(title)
          .fonts(titleFont)
          .foregroundStyle(foregroundColor)
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
    .background(Asset.Colors.surface.color)
  }
}

// MARK: - 편의 이니셜라이저 (Mercury 패턴 — 한쪽 슬롯만 쓸 때)

extension MutterNavigationBar where LeftContent == EmptyView {
  public init(
    _ backgroundColor: Color? = Asset.Colors.ivory.color,
    _ title: String? = nil,
    titleFont: MutterFont = .title,
    @ViewBuilder rightButtons: () -> RightContent
  ) {
    self.init(
      backgroundColor,
      title,
      titleFont: titleFont,
      leftButtons: { EmptyView()
      },
      rightButtons: rightButtons)
  }
}

extension MutterNavigationBar where RightContent == EmptyView {
  public init(
    _ backgroundColor: Color? = Asset.Colors.ivory.color,
    _ title: String? = nil,
    titleFont: MutterFont = .title,
    @ViewBuilder leftButtons: () -> LeftContent
  ) {
    self.init(
      backgroundColor,
      title,
      titleFont: titleFont,
      leftButtons: leftButtons,
      rightButtons: {
        EmptyView()
      })
  }
}

// MARK: - 뒤로가기 버튼

/// 표준 뒤로가기 버튼 — pop은 콜백으로 받는다(UIComponent는 Router를 모른다).
public struct MutterBackButton: View {
  private let foregroundColor: Color
  private let action: () -> Void

  public init(foregroundColor: Color = Asset.Colors.ink.color, action: @escaping () -> Void) {
    self.foregroundColor = foregroundColor
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      MutterIcon(Asset.Images.back, size: 22)
        .foregroundStyle(foregroundColor)
        .frame(width: 28, height: 28)
    }
  }
}

// MARK: - 화면 부착 모디파이어

public extension View {
  /// push된 화면 상단에 커스텀 내비바(뒤로가기 + 타이틀)를 얹고 시스템 내비바를 숨긴다.
  /// `safeAreaInset`이라 본문 레이아웃을 밀지 않고 안전영역만 확장한다.
  func mutterNavigationBar(backgroundColor: Color? = Asset.Colors.ivory.color, _ title: String? = nil, onBack: @escaping () -> Void) -> some View {
    self
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        MutterNavigationBar(
          backgroundColor,
          title,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )
      }
  }
}
