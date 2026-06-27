import SwiftUI

import Router
import UIComponent

/// 루트 탭 셸 — 5개 탭(홈·스레드·받은함·연결·프로필).
/// Feature→Feature 의존 0: 각 탭 콘텐츠는 합성 루트가 @ViewBuilder로 주입한다
/// (각 탭은 자체 NavigationStack을 포함해 전달되는 것을 권장).
public struct MainTabView<Home: View, Threads: View, Inbox: View, Connections: View, Profile: View>: View {
  @State private var selection: AppRoute = .home

  private let home: Home
  private let threads: Threads
  private let inbox: Inbox
  private let connections: Connections
  private let profile: Profile

  public init(
    @ViewBuilder home: () -> Home,
    @ViewBuilder threads: () -> Threads,
    @ViewBuilder inbox: () -> Inbox,
    @ViewBuilder connections: () -> Connections,
    @ViewBuilder profile: () -> Profile
  ) {
    self.home = home()
    self.threads = threads()
    self.inbox = inbox()
    self.connections = connections()
    self.profile = profile()
  }

  public var body: some View {
    TabView(selection: $selection) {
      home
        .tabItem { Label("홈", systemImage: "house.fill") }
        .tag(AppRoute.home)
      threads
        .tabItem { Label("주고받음", systemImage: "bubble.left.and.bubble.right.fill") }
        .tag(AppRoute.threads)
      inbox
        .tabItem { Label("받은함", systemImage: "tray.fill") }
        .tag(AppRoute.inbox)
      connections
        .tabItem { Label("연결", systemImage: "person.2.fill") }
        .tag(AppRoute.connections)
      profile
        .tabItem { Label("프로필", systemImage: "person.crop.circle.fill") }
        .tag(AppRoute.profile)
    }
    .tint(MutterColor.gold)
  }
}
