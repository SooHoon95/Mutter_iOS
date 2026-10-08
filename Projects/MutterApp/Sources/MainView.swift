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
  /// 최신 버전 미설치 시 전면 차단(강제 업데이트).
  @State private var forceUpdateRequired = false
  @Inject private var sessionManager: SessionManagable

  var body: some View {
    ZStack {
      currentView()

      // 강제 업데이트 차단 게이트 — 스플래시·로그인 상태와 무관하게 전면을 덮는다.
      if forceUpdateRequired {
        ForceUpdateView()
          .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: isSplashDone)
    .animation(.easeInOut(duration: 0.2), value: forceUpdateRequired)
    .environmentObject(coordinator)
    .task { await checkForceUpdate() }
    .task {
      // Lottie 스플래시가 최소 1회 재생되도록 최소 노출시간 확보(세션 확인이 즉시 끝나도 플래시 방지).
      let minSplash = Task { try? await Task.sleep(nanoseconds: 2_000_000_000) }
      await sessionManager.refresh()
      isUserLoggedIn = sessionManager.isLoggedIn
      await minSplash.value
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
      // Lottie 스플래시(Mercury CustomSplash 패턴). 세션 확인 + 최소 재생시간 후 dismiss.
      MutterSplashView()
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
      letterUsecase: LetterUsecase(repository: LetterRepository(), photoRepository: LetterPhotoRepository()),
      inboxUsecase: nil,
      audioUsecase: AudioUsecase(soundCloud: SoundCloudRepository()),
      onBack: { pendingLetter = nil }
    ).makeView(.token(token, password: nil))
  }

  // MARK: - Pending Connect Consumption

  /// App Store 최신 버전보다 설치 버전이 낮으면 강제 업데이트 게이트를 띄운다.
  /// 조회 실패 시엔 게이트를 띄우지 않는다(fail-open). 스토어 라이브 버전 기준이라
  /// 새 버전이 심사 통과·출시된 뒤에야 트리거된다.
  private func checkForceUpdate() async {
    let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    let bundleId = Bundle.main.bundleIdentifier ?? ""
    let usecase = AppUpdateUsecase(repository: AppUpdateRepository(bundleId: bundleId))
    if await usecase.isUpdateRequired(currentVersion: current) {
      forceUpdateRequired = true
    }
  }

  /// 보류 초대 토큰을 소비해 connect 화면으로 push. 로그인 완료 + 토큰 있을 때만 동작.
  private func consumePendingConnectIfNeeded() {
    guard isUserLoggedIn, let token = pendingConnectToken else { return }
    pendingConnectToken = nil
    coordinator.push(.connect(.invite(token: token)))
  }
}
