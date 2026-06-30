import SwiftUI

/// 받은함 탭 화면 계약. ViewWrapper가 채택해 `MainTabView`에 주입된다.
public protocol InboxViewable where Self: View {
  init()
}
