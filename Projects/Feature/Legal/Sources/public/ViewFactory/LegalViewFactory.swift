import SwiftUI

import Domain
import Router
import UIComponent

/// Legal 화면 팩토리. LegalRoute(신고/약관/개인정보)→화면.
/// 이용약관·개인정보처리방침은 웹의 정식 문서를 앱 안에서 연다(웹·Android와 같은 문서 하나를 본다).
public struct LegalViewFactory: ViewFactory {
  private let takedownUsecase: TakedownUsecasable
  private let termsURL: URL
  private let privacyURL: URL
  private let onBack: () -> Void

  /// - Parameters:
  ///   - termsURL: 웹 정식 이용약관 주소(`<링크 베이스>/legal/terms`).
  ///   - privacyURL: 웹 정식 개인정보처리방침 주소(`<링크 베이스>/legal/privacy`).
  public init(
    takedownUsecase: TakedownUsecasable,
    termsURL: URL,
    privacyURL: URL,
    onBack: @escaping () -> Void
  ) {
    self.takedownUsecase = takedownUsecase
    self.termsURL = termsURL
    self.privacyURL = privacyURL
    self.onBack = onBack
  }

  public func makeView(_ route: LegalRoute) -> some View {
    switch route {
    case .takedown:
      TakedownView(takedownUsecase: takedownUsecase, onBack: onBack)
    case .terms:
      LegalWebView(title: L10n.legalTerms, url: termsURL, onBack: onBack)
    case .privacy:
      LegalWebView(title: L10n.legalPrivacy, url: privacyURL, onBack: onBack)
    }
  }
}
