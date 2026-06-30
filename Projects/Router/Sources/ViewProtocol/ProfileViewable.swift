import SwiftUI

/// 프로필 탭 화면 계약. ViewWrapper가 채택해 `MainTabView`에 주입된다.
public protocol ProfileViewable where Self: View {
  init()
}
