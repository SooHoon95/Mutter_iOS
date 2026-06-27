import SwiftUI

/// Mutter 그림자 토큰. 웹 tokens.css의 shadow 이식. 색은 디자인 시스템 색만 사용(하드코딩 금지).
public struct MutterShadow {
  public let color: Color
  public let radius: CGFloat
  public let x: CGFloat
  public let y: CGFloat

  public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
    self.color = color
    self.radius = radius
    self.x = x
    self.y = y
  }

  /// 골드 CTA 하이라이트 그림자 (웹 --shadow-gold)
  public static let gold = MutterShadow(color: MutterColor.goldDeep.opacity(0.5), radius: 13, x: 0, y: 10)
  /// 부드러운 표면 그림자
  public static let soft = MutterShadow(color: MutterColor.ink.opacity(0.12), radius: 8, x: 0, y: 4)
}

public extension View {
  func mutterShadow(_ shadow: MutterShadow) -> some View {
    self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }
}
