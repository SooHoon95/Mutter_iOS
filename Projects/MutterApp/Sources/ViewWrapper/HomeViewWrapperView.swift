import SwiftUI

import AppFoundation
import Domain
import Home
import Infrastructure
import Router

/// 홈 탭 브리지(Mercury ViewWrapper 패턴). usecase는 `init`에서 그 자리에 조립해 생성자 주입하고,
/// 네비게이션 콜백은 환경의 코디네이터로 배선한다(로케이터 미사용).
struct HomeViewWrapperView: View, HomeViewable {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  private let letterUsecase: LetterUsecasable
  private let receiptUsecase: ReceiptUsecasable

  init() {
    self.letterUsecase = LetterUsecase(repository: LetterRepository())
    self.receiptUsecase = ReceiptUsecase(repository: ReceiptRepository())
  }

  var body: some View {
    HomeView(
      letterUsecase: letterUsecase,
      receiptUsecase: receiptUsecase,
      onCompose: { coordinator.push(.compose(.new)) },
      onEdit: { coordinator.push(.compose(.edit(letterId: $0))) },
      onPreview: { coordinator.push(.viewer(.myLetter(letterId: $0))) }
    )
  }
}
