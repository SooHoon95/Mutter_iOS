import SwiftUI

import Domain
import Router
import UIComponent

/// Legal 화면 팩토리. LegalRoute(신고/약관/개인정보)→화면.
/// 개인정보처리방침은 웹의 정식 문서를 앱 안에서 연다(웹·Android와 같은 문서 하나를 본다).
public struct LegalViewFactory: ViewFactory {
  private let takedownUsecase: TakedownUsecasable
  private let privacyURL: URL
  private let onBack: () -> Void

  /// - Parameter privacyURL: 웹 정식 개인정보처리방침 주소(`<링크 베이스>/legal/privacy`).
  public init(takedownUsecase: TakedownUsecasable, privacyURL: URL, onBack: @escaping () -> Void) {
    self.takedownUsecase = takedownUsecase
    self.privacyURL = privacyURL
    self.onBack = onBack
  }

  public func makeView(_ route: LegalRoute) -> some View {
    switch route {
    case .takedown:
      TakedownView(takedownUsecase: takedownUsecase, onBack: onBack)
    case .terms:
      LegalDocView(title: L10n.legalTerms, text: Self.termsText, onBack: onBack)
    case .privacy:
      LegalWebView(title: L10n.legalPrivacy, url: privacyURL, onBack: onBack)
    }
  }

  private static let termsText = """
  Mutter는 음악과 함께 전하는 편지 서비스입니다. 본 약관은 서비스 이용 조건을 정합니다.

  1. 이용자는 타인의 권리를 침해하는 콘텐츠를 게시하지 않습니다.
  2. 음원은 정식 라이선스(CC0 등) 또는 공식 임베드(SoundCloud)로만 제공됩니다.
  3. 서비스는 사전 고지 후 변경·중단될 수 있습니다.

  (정식 약관 전문은 추후 보강됩니다.)
  """
}
