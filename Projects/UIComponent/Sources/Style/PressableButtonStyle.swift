import SwiftUI

/// 탭 시 살짝 줄어드는 프레스 피드백 버튼 스타일.
/// 웹 `.openButton:active { transform: scale(0.97) }` 감성 이식.
public struct PressableButtonStyle: ButtonStyle {
  private let pressedScale: CGFloat
  private let pressedOpacity: CGFloat

  public init(pressedScale: CGFloat = 0.97, pressedOpacity: CGFloat = 0.9) {
    self.pressedScale = pressedScale
    self.pressedOpacity = pressedOpacity
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .opacity(configuration.isPressed ? pressedOpacity : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// 눌렀을 때 배경색만 바뀌는 스타일(리스트 행 등). Mercury `PressableBackgroundStyle` 패턴.
public struct PressableBackgroundStyle: ButtonStyle {
  private let normalColor: Color
  private let pressedColor: Color

  public init(normalColor: Color = .clear, pressedColor: Color) {
    self.normalColor = normalColor
    self.pressedColor = pressedColor
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(configuration.isPressed ? pressedColor : normalColor)
  }
}
