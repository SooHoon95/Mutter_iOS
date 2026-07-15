import SwiftUI
import UIKit

/// 편지 템플릿 테마(웹 `templates.ts`의 `TemplateTheme` 이식).
/// 색은 전부 `Asset.Colors.<테마><역할>`(예: `Asset.Colors.springDayBg`, xcassets 평탄) —
/// 테마별 콘텐츠 색이다. `id`는 웹/DB와 호환되는 문자열(Letter.templateId).
public struct LetterTheme: Identifiable, Equatable {
  public let id: String
  public let name: String
  public let summary: String

  // 색
  public let background: Color
  public let foreground: Color
  public let muted: Color
  public let accent: Color
  public let border: Color

  // 타이포그래피
  public let fontDesign: Font.Design
  public let bodySize: CGFloat
  public let headingSize: CGFloat
  /// 줄 높이 배수(웹 line-height). 본문 호흡감.
  public let lineHeightMultiplier: CGFloat

  // 레이아웃
  public let cornerRadius: CGFloat

  public static func == (lhs: LetterTheme, rhs: LetterTheme) -> Bool {
    lhs.id == rhs.id
  }

  /// 본문 폰트의 lineSpacing(목표 줄높이 - 폰트 실측 줄높이).
  public var bodyLineSpacing: CGFloat {
    Self.lineSpacing(size: bodySize, multiplier: lineHeightMultiplier, design: fontDesign)
  }

  /// 제목 폰트의 lineSpacing(제목은 1.4 배수 고정 — 웹 themes.css와 동일).
  public var headingLineSpacing: CGFloat {
    Self.lineSpacing(size: headingSize, multiplier: 1.4, design: fontDesign)
  }

  private static func lineSpacing(size: CGFloat, multiplier: CGFloat, design: Font.Design) -> CGFloat {
    let target = size * multiplier
    let uiFont = uiFont(size: size, design: design)
    return max(0, target - uiFont.lineHeight)
  }

  private static func uiFont(size: CGFloat, design: Font.Design) -> UIFont {
    let base = UIFont.systemFont(ofSize: size)
    let systemDesign: UIFontDescriptor.SystemDesign
    switch design {
    case .serif: systemDesign = .serif
    case .monospaced: systemDesign = .monospaced
    case .rounded: systemDesign = .rounded
    default: systemDesign = .default
    }
    if let descriptor = base.fontDescriptor.withDesign(systemDesign) {
      return UIFont(descriptor: descriptor, size: size)
    }
    return base
  }
}

// MARK: - 카탈로그 (웹 templates.ts 7종 이식)

public extension LetterTheme {
  /// 전체 테마(피커가 이터레이션). 웹 순서 유지.
  static let all: [LetterTheme] = [
    classicSerif, modernMinimal, warmCraft, nightSky, springDay, vintageTypewriter, pureSpace,
  ]

  static let defaultTheme = classicSerif

  /// id로 조회. 알 수 없는 id는 기본 테마로 안전 폴백(수신자 렌더 불변식).
  static func theme(id: String) -> LetterTheme {
    all.first { $0.id == id } ?? defaultTheme
  }

  static let classicSerif = LetterTheme(
    id: "classic-serif",
    name: L10n.themeClassicSerifName,
    summary: L10n.themeClassicSerifSummary,
    background: Asset.Colors.classicSerifBg.color,
    foreground: Asset.Colors.classicSerifFg.color,
    muted: Asset.Colors.classicSerifMuted.color,
    accent: Asset.Colors.classicSerifAccent.color,
    border: Asset.Colors.classicSerifBorder.color,
    fontDesign: .serif, bodySize: 17, headingSize: 22, lineHeightMultiplier: 1.85, cornerRadius: 4
  )

  static let modernMinimal = LetterTheme(
    id: "modern-minimal",
    name: L10n.themeModernMinimalName,
    summary: L10n.themeModernMinimalSummary,
    background: Asset.Colors.modernMinimalBg.color,
    foreground: Asset.Colors.modernMinimalFg.color,
    muted: Asset.Colors.modernMinimalMuted.color,
    accent: Asset.Colors.modernMinimalAccent.color,
    border: Asset.Colors.modernMinimalBorder.color,
    fontDesign: .default, bodySize: 16, headingSize: 20, lineHeightMultiplier: 1.75, cornerRadius: 2
  )

  static let warmCraft = LetterTheme(
    id: "warm-craft",
    name: L10n.themeWarmCraftName,
    summary: L10n.themeWarmCraftSummary,
    background: Asset.Colors.warmCraftBg.color,
    foreground: Asset.Colors.warmCraftFg.color,
    muted: Asset.Colors.warmCraftMuted.color,
    accent: Asset.Colors.warmCraftAccent.color,
    border: Asset.Colors.warmCraftBorder.color,
    fontDesign: .serif, bodySize: 16, headingSize: 21, lineHeightMultiplier: 1.8, cornerRadius: 6
  )

  static let nightSky = LetterTheme(
    id: "night-sky",
    name: L10n.themeNightSkyName,
    summary: L10n.themeNightSkySummary,
    background: Asset.Colors.nightSkyBg.color,
    foreground: Asset.Colors.nightSkyFg.color,
    muted: Asset.Colors.nightSkyMuted.color,
    accent: Asset.Colors.nightSkyAccent.color,
    border: Asset.Colors.nightSkyBorder.color,
    fontDesign: .serif, bodySize: 17, headingSize: 22, lineHeightMultiplier: 1.9, cornerRadius: 8
  )

  static let springDay = LetterTheme(
    id: "spring-day",
    name: L10n.themeSpringDayName,
    summary: L10n.themeSpringDaySummary,
    background: Asset.Colors.springDayBg.color,
    foreground: Asset.Colors.springDayFg.color,
    muted: Asset.Colors.springDayMuted.color,
    accent: Asset.Colors.springDayAccent.color,
    border: Asset.Colors.springDayBorder.color,
    fontDesign: .default, bodySize: 16, headingSize: 21, lineHeightMultiplier: 1.8, cornerRadius: 12
  )

  static let vintageTypewriter = LetterTheme(
    id: "vintage-typewriter",
    name: L10n.themeVintageTypewriterName,
    summary: L10n.themeVintageTypewriterSummary,
    background: Asset.Colors.vintageTypewriterBg.color,
    foreground: Asset.Colors.vintageTypewriterFg.color,
    muted: Asset.Colors.vintageTypewriterMuted.color,
    accent: Asset.Colors.vintageTypewriterAccent.color,
    border: Asset.Colors.vintageTypewriterBorder.color,
    fontDesign: .monospaced, bodySize: 15, headingSize: 20, lineHeightMultiplier: 1.9, cornerRadius: 0
  )

  static let pureSpace = LetterTheme(
    id: "pure-space",
    name: L10n.themePureSpaceName,
    summary: L10n.themePureSpaceSummary,
    background: Asset.Colors.pureSpaceBg.color,
    foreground: Asset.Colors.pureSpaceFg.color,
    muted: Asset.Colors.pureSpaceMuted.color,
    accent: Asset.Colors.pureSpaceAccent.color,
    border: Asset.Colors.pureSpaceBorder.color,
    fontDesign: .default, bodySize: 18, headingSize: 24, lineHeightMultiplier: 2.0, cornerRadius: 0
  )
}
