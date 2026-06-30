import SwiftUI

/// Mutter 기본 버튼(Mercury `MercuryButton` 패턴).
/// - primary: 골드 포일 그라데이션 CTA
/// - secondary: 연한 골드 표면
/// - ghost: 배경 없는 텍스트 버튼
/// 로딩/비활성 상태를 지원하고, 프레스 시 살짝 줄어든다.
public struct MutterButton: View {
  public enum Style {
    case primary
    case secondary
    case ghost
  }

  private let title: String
  private let style: Style
  private let isLoading: Bool
  private let isEnabled: Bool
  private let action: () -> Void

  public init(
    _ title: String,
    style: Style = .primary,
    isLoading: Bool = false,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.style = style
    self.isLoading = isLoading
    self.isEnabled = isEnabled
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      ZStack {
        Text(title)
          .fonts(.bodyLargeBold)
          .opacity(isLoading ? 0 : 1)

        if isLoading {
          ProgressView()
            .tint(foregroundColor)
        }
      }
      .foregroundStyle(foregroundColor)
      .frame(maxWidth: .infinity, minHeight: 54)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: MutterRadius.lg))
      .applyIf(style == .primary && isEnabled) { $0.shadows(.gold) }
    }
    .buttonStyle(PressableButtonStyle())
    .disabled(isLoading || !isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
  }

  /// 골드 포일 그라데이션(웹 --gold-gradient, 135°). primary CTA 배경.
  private static let goldGradient = LinearGradient(
    colors: [Asset.Colors.goldLight.color, Asset.Colors.gold.color, Asset.Colors.goldDeep.color],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  private var foregroundColor: Color {
    switch style {
    case .primary: Asset.Colors.onGold.color
    case .secondary, .ghost: Asset.Colors.ink.color
    }
  }

  @ViewBuilder
  private var background: some View {
    switch style {
    case .primary:
      Self.goldGradient
    case .secondary:
      Asset.Colors.goldSoft.color
    case .ghost:
      Color.clear
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    MutterButton("편지 보내기") {}
    MutterButton("취소", style: .secondary) {}
    MutterButton("나중에", style: .ghost) {}
    MutterButton("전송 중", isLoading: true) {}
    MutterButton("비활성", isEnabled: false) {}
  }
  .padding()
}
