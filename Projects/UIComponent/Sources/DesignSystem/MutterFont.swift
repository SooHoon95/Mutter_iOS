import SwiftUI

/// Mutter 타이포. 디스플레이=명조(serif), 본문=sans. (웹 tokens.css 스케일 이식)
/// NOTE: 현재 시스템 serif/sans. Nanum Myeongjo 커스텀 폰트는 `.ttf` 추가 후 교체한다
/// (UIAppFonts + Project.swift `resourceSynthesizers: [.fonts()]`).
public enum MutterFont {
  public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .serif)
  }

  public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
  }

  // 시맨틱 스케일
  public static let title = display(28, weight: .bold)
  public static let heading = display(20, weight: .semibold)
  public static let bodyLarge = body(18)
  public static let bodyMedium = body(16)
  public static let caption = body(14)
}
