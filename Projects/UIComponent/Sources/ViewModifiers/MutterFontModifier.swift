import SwiftUI

/// `MutterFont`를 적용하는 모디파이어.
/// SwiftUI 기본 `.font()`는 줄 높이(line-height)를 제어하지 못하므로,
/// UIFont 실측 lineHeight와 토큰 lineHeight 차이만큼 `lineSpacing`을 보정한다.
/// (Mercury `MercuryFontModifier` 패턴 — 편지/본문의 호흡감을 웹과 맞춘다.)
struct MutterFontModifier: ViewModifier {
  let mutterFont: MutterFont

  func body(content: Content) -> some View {
    let spacing = max(0, mutterFont.lineHeight - mutterFont.uiFont.lineHeight)
    return content
      .font(mutterFont.font)
      .lineSpacing(spacing)
  }
}

public extension View {
  /// Mutter 타이포 토큰을 적용한다. 예: `Text("열기").fonts(.bodyLargeBold)`
  func fonts(_ mutterFont: MutterFont) -> some View {
    modifier(MutterFontModifier(mutterFont: mutterFont))
  }
}
