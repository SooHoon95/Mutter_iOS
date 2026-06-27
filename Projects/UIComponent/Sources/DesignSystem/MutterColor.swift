import SwiftUI

/// Mutter 디자인 시스템 색. 값은 `Colors.xcassets`(SwiftGen `Asset.Colors`)에서 온다 — 코드 hex 하드코딩 금지.
/// Feature/컴포넌트는 `Asset` 직접 대신 이 시맨틱 API를 쓴다.
public enum MutterColor {
  /// 따뜻한 잉크 블랙 — heading/강조 텍스트
  public static let ink = Asset.Colors.ink.color
  /// 본문 텍스트
  public static let inkMid = Asset.Colors.inkMid.color
  /// 보조 텍스트
  public static let inkSoft = Asset.Colors.inkSoft.color
  /// 희미한 텍스트
  public static let inkFaint = Asset.Colors.inkFaint.color

  /// 골드 CTA/액센트
  public static let gold = Asset.Colors.gold.color
  /// 진한 골드 — 그라데이션 하단/그림자
  public static let goldDeep = Asset.Colors.goldDeep.color
  /// 연한 골드 — 표면/배지
  public static let goldSoft = Asset.Colors.goldSoft.color
  /// 골드 위 잉크(포일 엠보스)
  public static let onGold = Asset.Colors.onGold.color

  /// 웜 아이보리 — 편지지/기본 배경
  public static let ivory = Asset.Colors.ivory.color
  /// 순백 표면
  public static let surface = Asset.Colors.surface.color
}
