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
        .tabItem { tabLabel(L10n.tabHome, .home, Asset.Images.tabHome, Asset.Images.tabHomeFill) }
        .tag(AppRoute.home)
      ThreadsView()
        .tabItem { tabLabel(L10n.tabThreads, .threads, Asset.Images.tabThread, Asset.Images.tabThreadFill) }
        .tag(AppRoute.threads)
      InboxView()
        .tabItem { tabLabel(L10n.tabInbox, .inbox, Asset.Images.tabInbox, Asset.Images.tabInboxFill) }
        .tag(AppRoute.inbox)
      ConnectionsView()
        .tabItem { tabLabel(L10n.tabConnections, .connections, Asset.Images.tabPeople, Asset.Images.tabPeopleFill) }
        .tag(AppRoute.connections)
      ProfileView()
        .tabItem { tabLabel(L10n.tabProfile, .profile, Asset.Images.tabProfile, Asset.Images.tabProfileFill) }
        .tag(AppRoute.profile)
    }
    .tint(Asset.Colors.gold.color)
  }

  /// 선택 시 채움(fill), 아니면 라인 아이콘(디자인 시스템 탭바 페어). 탭바가 선택=골드/비선택=회색 틴팅.
  @ViewBuilder
  private func tabLabel(_ title: String, _ route: AppRoute, _ line: ImageAsset, _ fill: ImageAsset) -> some View {
    Label {
      Text(title)
    } icon: {
      (selection == route ? fill : line).image.renderingMode(.template)
    }
  }
}
