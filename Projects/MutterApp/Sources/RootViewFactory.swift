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
        .mutterNavigationBar(authTitle(authRoute), onBack: { coordinator.pop() })

    case .compose(let composeRoute):
      ComposeViewFactory(
        letterUsecase: LetterUsecase(repository: LetterRepository()),
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
        audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
        linkBaseURL: AppLink.baseURL,
        onDone: { coordinator.pop() }
      ).makeView(composeRoute)
        .mutterNavigationBar(composeTitle(composeRoute), onBack: { coordinator.pop() })

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
        linkBaseURL: AppLink.baseURL
      )
      .mutterNavigationBar("전달 링크", onBack: { coordinator.pop() })

    case .connect(let connectRoute):
      ConnectViewFactory(
        connectionUsecase: ConnectionUsecase(repository: ConnectionRepository()),
        onAccepted: { coordinator.popToRoot() }
      ).makeView(connectRoute)
        .mutterNavigationBar("초대", onBack: { coordinator.pop() })

    case .thread:
      // 스레드는 Threads 탭에서 시트로 처리한다(별도 push 미사용).
      EmptyView()

    case .legal(let legalRoute):
      LegalViewFactory(takedownUsecase: TakedownUsecase(repository: TakedownRepository())).makeView(legalRoute)
        .mutterNavigationBar(legalTitle(legalRoute), onBack: { coordinator.pop() })
    }
  }

  // MARK: - 라우트별 내비바 타이틀

  private func authTitle(_ route: AuthRoute) -> String {
    switch route {
    case .signIn: "로그인"
    case .onboardNickname: "닉네임 설정"
    }
  }

  private func composeTitle(_ route: ComposeRoute) -> String {
    switch route {
    case .new: "편지 쓰기"
    case .edit: "이어쓰기"
    case .reply: "답장"
    }
  }

  private func legalTitle(_ route: LegalRoute) -> String {
    switch route {
    case .takedown: "문의하기"
    case .terms: "이용약관"
    case .privacy: "개인정보 처리방침"
    }
  }
}
