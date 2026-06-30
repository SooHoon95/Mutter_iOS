import SwiftUI
import UIKit

/// 편지 템플릿 테마(웹 `templates.ts`의 `TemplateTheme` 이식).
/// 색은 전부 `Asset.Theme.*`(xcassets) — 디자인시스템 색(`Asset.Colors`)과 분리된
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
    name: "클래식 세리프",
    summary: "시대를 초월한 우아함. 손으로 쓴 편지의 감촉.",
    background: Asset.Theme.ClassicSerif.bg.color,
    foreground: Asset.Theme.ClassicSerif.fg.color,
    muted: Asset.Theme.ClassicSerif.muted.color,
    accent: Asset.Theme.ClassicSerif.accent.color,
    border: Asset.Theme.ClassicSerif.border.color,
    fontDesign: .serif, bodySize: 17, headingSize: 22, lineHeightMultiplier: 1.85, cornerRadius: 4
  )

  static let modernMinimal = LetterTheme(
    id: "modern-minimal",
    name: "모던 미니멀",
    summary: "여백이 말한다. 텍스트에만 집중.",
    background: Asset.Theme.ModernMinimal.bg.color,
    foreground: Asset.Theme.ModernMinimal.fg.color,
    muted: Asset.Theme.ModernMinimal.muted.color,
    accent: Asset.Theme.ModernMinimal.accent.color,
    border: Asset.Theme.ModernMinimal.border.color,
    fontDesign: .default, bodySize: 16, headingSize: 20, lineHeightMultiplier: 1.75, cornerRadius: 2
  )

  static let warmCraft = LetterTheme(
    id: "warm-craft",
    name: "따뜻한 크래프트",
    summary: "커피향 나는 브라운 톤. 오래된 카페의 감성.",
    background: Asset.Theme.WarmCraft.bg.color,
    foreground: Asset.Theme.WarmCraft.fg.color,
    muted: Asset.Theme.WarmCraft.muted.color,
    accent: Asset.Theme.WarmCraft.accent.color,
    border: Asset.Theme.WarmCraft.border.color,
    fontDesign: .serif, bodySize: 16, headingSize: 21, lineHeightMultiplier: 1.8, cornerRadius: 6
  )

  static let nightSky = LetterTheme(
    id: "night-sky",
    name: "밤하늘",
    summary: "깊은 남색 배경에 별빛 같은 문장들.",
    background: Asset.Theme.NightSky.bg.color,
    foreground: Asset.Theme.NightSky.fg.color,
    muted: Asset.Theme.NightSky.muted.color,
    accent: Asset.Theme.NightSky.accent.color,
    border: Asset.Theme.NightSky.border.color,
    fontDesign: .serif, bodySize: 17, headingSize: 22, lineHeightMultiplier: 1.9, cornerRadius: 8
  )

  static let springDay = LetterTheme(
    id: "spring-day",
    name: "봄날",
    summary: "연분홍 벚꽃처럼 가볍고 설레는 마음.",
    background: Asset.Theme.SpringDay.bg.color,
    foreground: Asset.Theme.SpringDay.fg.color,
    muted: Asset.Theme.SpringDay.muted.color,
    accent: Asset.Theme.SpringDay.accent.color,
    border: Asset.Theme.SpringDay.border.color,
    fontDesign: .default, bodySize: 16, headingSize: 21, lineHeightMultiplier: 1.8, cornerRadius: 12
  )

  static let vintageTypewriter = LetterTheme(
    id: "vintage-typewriter",
    name: "빈티지 타자기",
    summary: "타자기 서체로 찍힌 진심. 아날로그의 온기.",
    background: Asset.Theme.VintageTypewriter.bg.color,
    foreground: Asset.Theme.VintageTypewriter.fg.color,
    muted: Asset.Theme.VintageTypewriter.muted.color,
    accent: Asset.Theme.VintageTypewriter.accent.color,
    border: Asset.Theme.VintageTypewriter.border.color,
    fontDesign: .monospaced, bodySize: 15, headingSize: 20, lineHeightMultiplier: 1.9, cornerRadius: 0
  )

  static let pureSpace = LetterTheme(
    id: "pure-space",
    name: "순수 여백",
    summary: "극도의 미니멀. 말 한마디가 전부인 편지.",
    background: Asset.Theme.PureSpace.bg.color,
    foreground: Asset.Theme.PureSpace.fg.color,
    muted: Asset.Theme.PureSpace.muted.color,
    accent: Asset.Theme.PureSpace.accent.color,
    border: Asset.Theme.PureSpace.border.color,
    fontDesign: .default, bodySize: 18, headingSize: 24, lineHeightMultiplier: 2.0, cornerRadius: 0
  )
}
