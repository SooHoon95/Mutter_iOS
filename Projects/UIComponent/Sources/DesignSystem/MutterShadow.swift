import SwiftUI

/// Mutter 그림자 토큰. 웹 `tokens.css`의 shadow 이식.
/// 색은 디자인 시스템 색(`Asset.Colors`)만 사용한다 — hex 하드코딩 금지.
/// `.shadows(_:)` 모디파이어로 적용한다(Mercury `MercuryShadow` 패턴).
public enum MutterShadow {
  case shadowLow
  case shadowMediumLow
  case shadowMedium
  case shadowHigh
  case shadowHighest
  
  var opacity: CGFloat {
    switch self {
    case .shadowLow:
      0.06
    case .shadowMediumLow:
      0.08
    case .shadowMedium:
      0.10
    case .shadowHigh:
      0.13
    case .shadowHighest:
      0.18
    }
  }
  
  var yDirection: CGFloat {
    switch self {
    case .shadowLow:
      2
    case .shadowMediumLow:
      3
    case .shadowMedium:
      4
    case .shadowHigh:
      6
    case .shadowHighest:
      8
    }
  }
  
  var xDirection: CGFloat {
    .zero
  }
  
  var blur: CGFloat {
    switch self {
    case .shadowLow:
      6
    case .shadowMediumLow:
      12
    case .shadowMedium:
      16
    case .shadowHigh:
      24
    case .shadowHighest:
      32
    }
  }
}
