import SwiftUI

import Router

import AuthFeature
import Compose
import Connections
import Delivery
import Legal
import Viewer

/// 마스터 화면 팩토리 — push되는 FeatureRoute를 각 Feature의 ViewFactory로 위임한다.
/// 콜백(pop/popToRoot/인증완료)을 NavigationCoordinator에 배선한다.
@MainActor
struct RootViewFactory {
  let deps: AppDependencies
  let coordinator: NavigationCoordinator<FeatureRoute>
  var onAuthenticated: () -> Void = {}

  @ViewBuilder
  func makeView(_ route: FeatureRoute) -> some View {
    switch route {
    case .auth(let authRoute):
      AuthViewFactory(
        authUsecase: deps.authUsecase,
        profileUsecase: deps.profileUsecase,
        onAuthenticated: onAuthenticated,
        onOnboarded: { coordinator.popToRoot() }
      ).makeView(authRoute)

    case .compose(let composeRoute):
      ComposeViewFactory(
        letterUsecase: deps.letterUsecase,
        catalogUsecase: deps.catalogUsecase,
        connectionUsecase: deps.connectionUsecase,
        audioUsecase: deps.audioUsecase,
        onDone: { coordinator.pop() }
      ).makeView(composeRoute)

    case .viewer(let viewerRoute):
      ViewerViewFactory(
        deliveryUsecase: deps.deliveryUsecase,
        receiptUsecase: deps.receiptUsecase,
        letterUsecase: deps.letterUsecase,
        audioUsecase: deps.audioUsecase
      ).makeView(viewerRoute)

    case .delivery(let letterId):
      DeliveryView(letterId: letterId, deliveryUsecase: deps.deliveryUsecase, linkBaseURL: deps.linkBaseURL)

    case .connect(let connectRoute):
      ConnectViewFactory(
        connectionUsecase: deps.connectionUsecase,
        onAccepted: { coordinator.popToRoot() }
      ).makeView(connectRoute)

    case .thread:
      // 스레드는 Threads 탭에서 시트로 처리한다(별도 push 미사용).
      EmptyView()

    case .legal(let legalRoute):
      LegalViewFactory(takedownUsecase: deps.takedownUsecase).makeView(legalRoute)
    }
  }
}
