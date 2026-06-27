import SwiftUI

/// Mutter 그림자 토큰. 웹 `tokens.css`의 shadow 이식.
/// 색은 디자인 시스템 색(`MutterColor`)만 사용한다 — hex 하드코딩 금지.
/// `.shadows(_:)` 모디파이어로 적용한다(Mercury `MercuryShadow` 패턴).
public enum MutterShadow {
  /// 부드러운 표면 그림자 (웹 --shadow-soft)
  case soft
  /// 카드 그림자 (웹 --shadow-card)
  case card
  /// 골드 CTA 하이라이트 (웹 --shadow-gold)
  case gold

  var color: Color {
    switch self {
    case .soft, .card: MutterColor.ink
    case .gold: MutterColor.goldDeep
    }
  }

  var opacity: CGFloat {
    switch self {
    case .soft: 0.12
    case .card: 0.16
    case .gold: 0.5
    }
  }

  var radius: CGFloat {
    switch self {
    case .soft: 8
    case .card: 16
    case .gold: 13
    }
  }

  var x: CGFloat { 0 }

  var y: CGFloat {
    switch self {
    case .soft: 4
    case .card: 8
    case .gold: 10
    }
  }
}
