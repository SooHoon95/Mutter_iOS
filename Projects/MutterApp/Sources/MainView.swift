import Combine
import SwiftUI

import AppFoundation
import Domain
import Infrastructure
import Router
import UIComponent

import Viewer

/// 딥링크 편지 토큰 — fullScreenCover item으로 사용(Identifiable).
private struct DeeplinkToken: Identifiable {
  let id: String
  var token: String { id }
}

/// 앱 루트(Mercury `MainView` 패턴) — splash(loading) → signin → maintab 단계 전환.
/// 세션 상태는 `SessionManagable` 스트림이 단일 소스.
/// 딥링크 처리:
///   - 로그인 완료 상태: 즉시 coordinator push.
///   - 미로그인 / splash 대기 중:
///     · 편지(/l/:token) → fullScreenCover로 미인증 뷰어 즉시 표시(수신자 무마찰).
///     · 초대(/connect/:token) → pendingConnectToken에 보류, 로그인 완료 시 소비.
struct MainView: View {
  @StateObject private var coordinator = NavigationCoordinator<FeatureRoute>()
  @State private var isSplashDone = false
  @State private var isUserLoggedIn = false
  /// 미인증/splash 중 수신된 편지 딥링크 — fullScreenCover로 즉시 열람(EC-5.1).
  @State private var pendingLetter: DeeplinkToken?
  /// 미인증/splash 중 수신된 초대 딥링크 — 로그인 완료 시 소비(EC-5.2/5.5).
  @State private var pendingConnectToken: String?
  @Inject private var sessionManager: SessionManagable

  var body: some View {
    ZStack {
      currentView()
    }
    .animation(.easeInOut(duration: 0.25), value: isSplashDone)
    .environmentObject(coordinator)
    .task {
      await sessionManager.refresh()
      isUserLoggedIn = sessionManager.isLoggedIn
      isSplashDone = true
      // splash 완료 시점에 이미 로그인돼 있으면 보류 초대 토큰 소비(cold-start-logged-in, EC-5.5).
      consumePendingConnectIfNeeded()
    }
    .onReceive(sessionManager.isLoggedInStream) { loggedIn in
      guard isSplashDone else { return }
      guard isUserLoggedIn != loggedIn else { return }
      if !loggedIn { coordinator.popToRoot() }
      isUserLoggedIn = loggedIn
      // 로그인 완료 시 보류 초대 딥링크 소비(EC-5.2 — 우연 동작을 설계 보장으로).
      if loggedIn { consumePendingConnectIfNeeded() }
    }
    .onOpenURL { url in
      // 소셜 OAuth 콜백이면 SDK가 소진, 아니면 앱 딥링크(수신 라우트)로 폴백.
      if OauthDeepLinkHandler.shared.handle(url: url) { return }
      guard let deeplink = Deeplink(url: url) else { return }
      switch deeplink {
      case .letter(let token):
        if isSplashDone && isUserLoggedIn {
          // 로그인 완료 상태 — NavigationStack이 마운트돼 있으므로 바로 push.
          coordinator.push(.viewer(.token(token, password: nil)))
        } else {
          // 미로그인 또는 splash 대기 중 — fullScreenCover로 미인증 뷰어 즉시 표시(EC-5.1).
          pendingLetter = DeeplinkToken(id: token)
        }
      case .connect(let token):
        if isSplashDone && isUserLoggedIn {
          // 로그인 완료 상태 — 초대 화면 push.
          coordinator.push(.connect(.invite(token: token)))
        } else {
          // 미로그인 또는 splash 대기 중 — 로그인 완료 후 소비(EC-5.2/5.5).
          pendingConnectToken = token
        }
      }
    }
    // 미인증 편지 뷰어 — NavigationStack 마운트 여부와 무관하게 any-state에서 표시(EC-5.1).
    .fullScreenCover(item: $pendingLetter) { item in
      unauthenticatedViewerCover(token: item.token)
    }
  }

  // MARK: - Current View

  @ViewBuilder
  private func currentView() -> some View {
    if !isSplashDone {
      // 세션 확인 대기(추후 CustomSplash로 교체 가능한 지점).
      ZStack {
        Asset.Colors.ivory.color.ignoresSafeArea()
        ProgressView().tint(Asset.Colors.gold.color)
      }
    } else if !isUserLoggedIn {
      AuthViewWrapperView(onComplete: { Task { await sessionManager.refresh() } })
    } else {
      NavigationStack(path: $coordinator.rootStack) {
        MainTabViewWrapperView()
          .navigationDestination(for: FeatureRoute.self) { route in
            RootViewFactory(coordinator: coordinator).makeView(route)
          }
      }
      .fullScreenCover(isPresented: $coordinator.isFullScreenPresented) {
        fullScreenCoverContent()
          .environmentObject(coordinator)
      }
    }
  }

  @ViewBuilder
  private func fullScreenCoverContent() -> some View {
    if let route = coordinator.fullScreenRoute {
      NavigationStack(path: $coordinator.fullScreenStack) {
        RootViewFactory(coordinator: coordinator).makeView(route)
          .navigationDestination(for: FeatureRoute.self) { route in
            RootViewFactory(coordinator: coordinator).makeView(route)
          }
      }
    }
  }

  // MARK: - Unauthenticated Viewer Cover

  /// 미인증 편지 뷰어 — inboxUsecase: nil(능력 부재). 닫기 버튼으로 dismiss.
  @ViewBuilder
  private func unauthenticatedViewerCover(token: String) -> some View {
    // 뒤로가기 = 커버 닫기(push 화면들과 내비바 UI 통일).
    // 뒤로가기 = 커버 닫기. 뷰어가 내부에서 테마 정합 내비바를 직접 얹으므로(MU-7)
    // 라우팅 레이어 modifier 없이 onBack만 주입한다.
    ViewerViewFactory(
      deliveryUsecase: DeliveryUsecase(repository: DeliveryRepository()),
      receiptUsecase: ReceiptUsecase(repository: ReceiptRepository()),
      letterUsecase: LetterUsecase(repository: LetterRepository()),
      inboxUsecase: nil,
      audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
      onBack: { pendingLetter = nil }
    ).makeView(.token(token, password: nil))
  }

  // MARK: - Pending Connect Consumption

  /// 보류 초대 토큰을 소비해 connect 화면으로 push. 로그인 완료 + 토큰 있을 때만 동작.
  private func consumePendingConnectIfNeeded() {
    guard isUserLoggedIn, let token = pendingConnectToken else { return }
    pendingConnectToken = nil
    coordinator.push(.connect(.invite(token: token)))
  }
}
