import SwiftUI
import UIKit

/// Mutter 타이포그래피 토큰.
/// 앱 크롬(버튼·네비바·토스트·화면 제목)에 쓰는 시맨틱 폰트 스케일.
/// - 편지 본문 자체는 테마별 폰트(`LetterTheme`)를 쓰므로 여기 정의를 쓰지 않는다.
/// - 디스플레이/제목 = serif(명조 계열 감성), 본문/UI = sans.
/// - 현재 시스템 폰트(serif/default design). Nanum Myeongjo `.ttf`는 추후
///   `resourceSynthesizers: [.fonts()]` + `FontFamily`로 교체한다.
/// - `.fonts(_:)` 모디파이어가 size/weight/design + lineHeight 보정을 한 번에 적용한다.
public enum MutterFont {
  /// 워드마크/히어로 — 명조 40
  case display
  /// 편지 제목 / 화면 큰 제목 — 명조 24 Bold
  case titleLarge
  /// 섹션 제목 — 명조 20 Semibold
  case title
  /// 헤드라인 — sans 18 Semibold
  case headline
  /// 버튼/강조 본문 — sans 17 Bold
  case bodyLargeBold
  /// 본문 큰 — sans 17 Regular
  case bodyLarge
  /// 본문 강조 — sans 16 Semibold
  case bodyMediumBold
  /// 본문 — sans 16 Regular
  case bodyMedium
  /// 보조 본문 — sans 15 Regular
  case bodySmall
  /// 캡션 강조 — sans 13 Semibold
  case captionBold
  /// 캡션 — sans 13 Regular
  case caption

  /// 폰트 크기(pt)
  public var size: CGFloat {
    switch self {
    case .display: 40
    case .titleLarge: 24
    case .title: 20
    case .headline: 18
    case .bodyLargeBold, .bodyLarge: 17
    case .bodyMediumBold, .bodyMedium: 16
    case .bodySmall: 15
    case .captionBold, .caption: 13
    }
  }

  /// 줄 높이(pt) — 본문 가독성을 위해 크기보다 넉넉히.
  public var lineHeight: CGFloat {
    switch self {
    case .display: 48
    case .titleLarge: 32
    case .title: 28
    case .headline: 26
    case .bodyLargeBold, .bodyLarge: 26
    case .bodyMediumBold, .bodyMedium: 24
    case .bodySmall: 22
    case .captionBold, .caption: 18
    }
  }

  public var weight: Font.Weight {
    switch self {
    case .display, .titleLarge, .bodyLargeBold: .bold
    case .title, .headline, .bodyMediumBold, .captionBold: .semibold
    case .bodyLarge, .bodyMedium, .bodySmall, .caption: .regular
    }
  }

  /// serif(명조 감성) vs default(sans).
  public var design: Font.Design {
    switch self {
    case .display, .titleLarge, .title: .serif
    default: .default
    }
  }

  /// SwiftUI Font 값.
  public var font: Font {
    .system(size: size, weight: weight, design: design)
  }

  /// lineHeight 보정을 위한 UIFont(실측 lineHeight 계산용).
  var uiFont: UIFont {
    let uiWeight = weight.uiWeight
    let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
    if design == .serif, let descriptor = base.fontDescriptor.withDesign(.serif) {
      return UIFont(descriptor: descriptor, size: size)
    }
    return base
  }
}

private extension Font.Weight {
  /// SwiftUI Font.Weight → UIFont.Weight 매핑(lineHeight 실측용).
  var uiWeight: UIFont.Weight {
    switch self {
    case .bold: .bold
    case .semibold: .semibold
    case .medium: .medium
    case .heavy: .heavy
    case .light: .light
    case .thin: .thin
    default: .regular
    }
  }
}
