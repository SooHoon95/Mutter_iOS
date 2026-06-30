import SwiftUI

/// 주고받음(스레드) 탭 화면 계약. ViewWrapper가 채택해 `MainTabView`에 주입된다.
public protocol ThreadsViewable where Self: View {
  init()
}
