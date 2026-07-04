import SwiftUI

/// `MutterShadow` 토큰을 적용하는 모디파이어(Mercury `MercuryShadowModifier` 패턴).
struct MutterShadowModifier: ViewModifier {
  let shadow: MutterShadow
  
  func body(content: Content) -> some View {
    content
      .shadow(
        color: Asset.Colors.ink.color.opacity(shadow.opacity),
        radius: shadow.blur / 2,
        x: shadow.xDirection,
        y: shadow.yDirection
      )
  }
}

public extension View {
  /// Mutter 그림자 토큰을 적용한다. 예: `card.shadows(.shadowMediumLow)`
  func shadows(_ shadow: MutterShadow) -> some View {
    modifier(MutterShadowModifier(shadow: shadow))
  }
}
