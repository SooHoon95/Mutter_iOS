import SwiftUI

/// `MutterShadow` 토큰을 적용하는 모디파이어(Mercury `MercuryShadowModifier` 패턴).
struct MutterShadowModifier: ViewModifier {
  let shadow: MutterShadow

  func body(content: Content) -> some View {
    content.shadow(
      color: shadow.color.opacity(shadow.opacity),
      radius: shadow.radius,
      x: shadow.x,
      y: shadow.y
    )
  }
}

public extension View {
  /// Mutter 그림자 토큰을 적용한다. 예: `card.shadows(.card)`
  func shadows(_ shadow: MutterShadow) -> some View {
    modifier(MutterShadowModifier(shadow: shadow))
  }
}
