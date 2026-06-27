import SwiftUI

import Router
import UIComponent

import AuthFeature
import Connections
import Home
import Inbox
import MainTab
import Profile
import Threads

/// 앱 루트 — 인증 게이트(미로그인→Auth) → MainTab(탭별 콜백 + push 네비게이션 + 딥링크).
struct RootView: View {
  enum Phase {
    case loading
    case signedOut
    case signedIn
  }

  @StateObject private var coordinator = NavigationCoordinator<FeatureRoute>()
  @State private var phase: Phase = .loading

  private let deps: AppDependencies

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var body: some View {
    Group {
      switch phase {
      case .loading:
        ZStack { MutterColor.ivory.ignoresSafeArea(); ProgressView().tint(MutterColor.gold) }
      case .signedOut:
        authGate
      case .signedIn:
        mainStack
      }
    }
    .task {
      let session = await deps.authUsecase.currentSession()
      phase = session != nil ? .signedIn : .signedOut
    }
    .onOpenURL { url in
      // 딥링크는 로그인 여부와 무관하게 수신 라우트로(무마찰). 수신 화면은 무계정 허용.
      if let route = DeeplinkRouter.route(for: url) {
        coordinator.push(route)
      }
    }
  }

  private var authGate: some View {
    AuthViewFactory(
      authUsecase: deps.authUsecase,
      profileUsecase: deps.profileUsecase,
      onAuthenticated: { phase = .signedIn },
      onOnboarded: { phase = .signedIn }
    ).makeView(.signIn)
  }

  private var mainStack: some View {
    let factory = RootViewFactory(
      deps: deps,
      coordinator: coordinator,
      onAuthenticated: { phase = .signedIn }
    )
    return NavigationStack(path: $coordinator.rootStack) {
      MainTabView(
        home: {
          HomeView(
            letterUsecase: deps.letterUsecase,
            receiptUsecase: deps.receiptUsecase,
            onCompose: { coordinator.push(.compose(.new)) },
            onEdit: { coordinator.push(.compose(.edit(letterId: $0))) },
            onPreview: { coordinator.push(.viewer(.myLetter(letterId: $0))) }
          )
        },
        threads: {
          ThreadsView(
            threadUsecase: deps.threadUsecase,
            onReply: { coordinator.push(.compose(.reply(recipientId: $0))) },
            onOpen: { coordinator.push(.viewer(.token($0, password: nil))) }
          )
        },
        inbox: {
          InboxView(
            inboxUsecase: deps.inboxUsecase,
            onOpen: { coordinator.push(.viewer(.token($0, password: nil))) }
          )
        },
        connections: {
          ConnectionsView(connectionUsecase: deps.connectionUsecase, inviteBaseURL: deps.linkBaseURL)
        },
        profile: {
          ProfileView(
            profileUsecase: deps.profileUsecase,
            authUsecase: deps.authUsecase,
            onSignedOut: { phase = .signedOut }
          )
        }
      )
      .navigationDestination(for: FeatureRoute.self) { route in
        factory.makeView(route)
      }
    }
  }
}
