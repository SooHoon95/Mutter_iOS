import SwiftUI

import Router
import UIComponent

/// 루트 탭 셸 — 5개 탭(홈·스레드·받은함·연결·프로필).
/// Feature→Feature 의존 0: 각 탭 콘텐츠 타입은 Router `*Viewable` 프로토콜로만 제약하고,
/// 구체 타입(합성 루트의 ViewWrapper)은 제네릭 인자로 주입받아 `init()`으로 생성한다(Mercury 패턴).
public struct MainTabView<
  HomeView: HomeViewable,
  ThreadsView: ThreadsViewable,
  InboxView: InboxViewable,
  ConnectionsView: ConnectionsViewable,
  ProfileView: ProfileViewable
>: View {
  @State private var selection: AppRoute = .home

  public init() {}

  public var body: some View {
    TabView(selection: $selection) {
      HomeView()
        .tabItem { Label("홈", systemImage: "house.fill") }
        .tag(AppRoute.home)
      ThreadsView()
        .tabItem { Label("주고받음", systemImage: "bubble.left.and.bubble.right.fill") }
        .tag(AppRoute.threads)
      InboxView()
        .tabItem { Label("받은함", systemImage: "tray.fill") }
        .tag(AppRoute.inbox)
      ConnectionsView()
        .tabItem { Label("연결", systemImage: "person.2.fill") }
        .tag(AppRoute.connections)
      ProfileView()
        .tabItem { Label("프로필", systemImage: "person.crop.circle.fill") }
        .tag(AppRoute.profile)
    }
    .tint(Asset.Colors.gold.color)
  }
}
