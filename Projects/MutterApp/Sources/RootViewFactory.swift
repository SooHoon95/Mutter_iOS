import SwiftUI

import AppFoundation
import Domain
import Infrastructure
import Router
import UIComponent

import AuthFeature
import Compose
import Connections
import Delivery
import Legal
import Viewer

/// 마스터 화면 팩토리 — push되는 FeatureRoute를 각 Feature의 ViewFactory로 위임한다.
/// usecase는 컨테이너에서 꺼내지 않고 각 라우트에서 `Usecase(repository: Repository())`로 그 자리에 조립해
/// 생성자 주입한다(Mercury 패턴 — 로케이터엔 세션 등 전역만). pop/popToRoot 콜백은 코디네이터에 배선.
/// push되는 모든 화면은 시스템 내비바를 숨기고 `MutterNavigationBar`(뒤로가기=coordinator.pop)를 얹는다.
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
      // navbar는 ComposeView 내부에서 Component로 직접 얹는다(모디파이어 제거).
      ComposeViewFactory(
        letterUsecase: LetterUsecase(repository: LetterRepository()),
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
        linkBaseURL: AppLink.baseURL,
        onDone: { coordinator.pop() },
        onBack: { coordinator.pop() }
      ).makeView(composeRoute)

    case .viewer(let viewerRoute):
      // 뷰어는 편지 테마색과 내비바를 맞추려 내부에서 내비바를 Component로 직접 얹는다(MU-7).
      // 따라서 라우팅 레이어 modifier를 붙이지 않고 onBack만 주입한다.
      ViewerViewFactory(
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        receiptUsecase: ReceiptUsecase(repository: ReceiptRepository()),
        letterUsecase: LetterUsecase(repository: LetterRepository()),
        inboxUsecase: InboxUsecase(repository: InboxRepository()),
        audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
        onBack: { coordinator.pop() }
      ).makeView(viewerRoute)

    case .delivery(let letterId):
      DeliveryView(
        letterId: letterId,
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        linkBaseURL: AppLink.baseURL,
        navTitle: L10n.deliveryNav,
        onPreview: { coordinator.push(.viewer(.myLetter(letterId: letterId))) },
        onBack: { coordinator.pop() }
      )

    case .connect(let connectRoute):
      ConnectViewFactory(
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        onAccepted: { coordinator.popToRoot() },
        onBack: { coordinator.pop() }
      ).makeView(connectRoute)

    case .thread:
      // 스레드는 Threads 탭에서 시트로 처리한다(별도 push 미사용).
      EmptyView()

    case .legal(let legalRoute):
      LegalViewFactory(
        takedownUsecase: TakedownUsecase(repository: TakedownRepository()),
        onBack: { coordinator.pop() }
      ).makeView(legalRoute)
    }
  }
}
