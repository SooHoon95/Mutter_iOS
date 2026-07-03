import SwiftUI

import AppFoundation
import Domain
import Infrastructure
import Router

import AuthFeature
import Compose
import Connections
import Delivery
import Legal
import Viewer

/// 마스터 화면 팩토리 — push되는 FeatureRoute를 각 Feature의 ViewFactory로 위임한다.
/// usecase는 컨테이너에서 꺼내지 않고 각 라우트에서 `Usecase(repository: Repository())`로 그 자리에 조립해
/// 생성자 주입한다(Mercury 패턴 — 로케이터엔 세션 등 전역만). pop/popToRoot 콜백은 코디네이터에 배선.
@MainActor
struct RootViewFactory {
  let coordinator: NavigationCoordinator<FeatureRoute>
  var onAuthenticated: () -> Void = {}

  @ViewBuilder
  func makeView(_ route: FeatureRoute) -> some View {
    switch route {
    case .auth(let authRoute):
      AuthViewFactory(
        authUsecase: AuthUsecase(repository: AuthRepository()),
        profileUsecase: ProfileUsecase(repository: ProfileRepository()),
        onAuthenticated: onAuthenticated,
        onOnboarded: { coordinator.popToRoot() }
      ).makeView(authRoute)

    case .compose(let composeRoute):
      ComposeViewFactory(
        letterUsecase: LetterUsecase(repository: LetterRepository()),
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
        linkBaseURL: AppLink.baseURL,
        onDone: { coordinator.pop() }
      ).makeView(composeRoute)

    case .viewer(let viewerRoute):
      ViewerViewFactory(
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        receiptUsecase: ReceiptUsecase(repository: ReceiptRepository()),
        letterUsecase: LetterUsecase(repository: LetterRepository()),
        inboxUsecase: InboxUsecase(repository: InboxRepository()),
        audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository())
      ).makeView(viewerRoute)

    case .delivery(let letterId):
      DeliveryView(
        letterId: letterId,
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        linkBaseURL: AppLink.baseURL
      )

    case .connect(let connectRoute):
      ConnectViewFactory(
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        onAccepted: { coordinator.popToRoot() }
      ).makeView(connectRoute)

    case .thread:
      // 스레드는 Threads 탭에서 시트로 처리한다(별도 push 미사용).
      EmptyView()

    case .legal(let legalRoute):
      LegalViewFactory(takedownUsecase: TakedownUsecase(repository: TakedownRepository())).makeView(legalRoute)
    }
  }
}
