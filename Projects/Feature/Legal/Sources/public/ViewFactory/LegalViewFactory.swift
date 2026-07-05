import SwiftUI

import Domain
import Router

/// Legal 화면 팩토리. LegalRoute(신고/약관/개인정보)→화면.
public struct LegalViewFactory: ViewFactory {
  private let takedownUsecase: TakedownUsecasable
  private let onBack: () -> Void

  public init(takedownUsecase: TakedownUsecasable, onBack: @escaping () -> Void) {
    self.takedownUsecase = takedownUsecase
    self.onBack = onBack
  }

  public func makeView(_ route: LegalRoute) -> some View {
    switch route {
    case .takedown:
      TakedownView(takedownUsecase: takedownUsecase, onBack: onBack)
    case .terms:
      LegalDocView(title: "이용약관", text: Self.termsText, onBack: onBack)
    case .privacy:
      LegalDocView(title: "개인정보처리방침", text: Self.privacyText, onBack: onBack)
    }
  }

  private static let termsText = """
  Mutter는 음악과 함께 전하는 편지 서비스입니다. 본 약관은 서비스 이용 조건을 정합니다.

  1. 이용자는 타인의 권리를 침해하는 콘텐츠를 게시하지 않습니다.
  2. 음원은 정식 라이선스(CC0 등) 또는 공식 임베드(SoundCloud)로만 제공됩니다.
  3. 서비스는 사전 고지 후 변경·중단될 수 있습니다.

  (정식 약관 전문은 추후 보강됩니다.)
  """

  private static let privacyText = """
  Mutter는 최소한의 정보만 수집합니다.

  1. 계정: 이메일(로그인), 닉네임(표시).
  2. 편지·연결 데이터는 본인과 수신자만 접근할 수 있도록 보호됩니다.
  3. 전달 링크는 추측 불가 토큰 + 암호로 보호되며 색인되지 않습니다.

  (정식 처리방침 전문은 추후 보강됩니다.)
  """
}
