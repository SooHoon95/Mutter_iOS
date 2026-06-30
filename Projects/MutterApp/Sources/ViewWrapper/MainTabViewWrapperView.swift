import SwiftUI

import MainTab
import Router

/// 루트 탭 셸 브리지. 5개 탭 ViewWrapper를 `MainTabView`의 제네릭 인자로 묶어 `MainView`에 주입한다.
struct MainTabViewWrapperView: View, MainTabViewable {
  init() {}

  var body: some View {
    MainTabView<
      HomeViewWrapperView,
      ThreadsViewWrapperView,
      InboxViewWrapperView,
      ConnectionsViewWrapperView,
      ProfileViewWrapperView
    >()
  }
}
