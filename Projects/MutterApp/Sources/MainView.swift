import Combine
import SwiftUI

import AppFoundation
import Router
import UIComponent

/// 앱 루트(Mercury `MainView` 패턴) — splash(loading) → signin → maintab 단계 전환.
/// 세션 상태는 `SessionManagable` 스트림이 단일 소스. 딥링크는 로그인 여부와 무관하게 수신 라우트로 push.
struct MainView: View {
  @StateObject private var coordinator = NavigationCoordinator<FeatureRoute>()
  @State private var isSplashDone = false
  @State private var isUserLoggedIn = false
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
    }
    .onReceive(sessionManager.isLoggedInStream) { loggedIn in
      guard isSplashDone else { return }
      guard isUserLoggedIn != loggedIn else { return }
      if !loggedIn { coordinator.popToRoot() }
      isUserLoggedIn = loggedIn
    }
    .onOpenURL { url in
      // 딥링크는 무계정 허용(수신 화면). 로그인 여부와 무관하게 수신 라우트로 push.
      if let route = DeeplinkRouter.route(for: url) {
        coordinator.push(route)
      }
    }
  }

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
}
