import SwiftUI

/// 루트 탭 셸 화면 계약. 합성 루트의 `MainTabViewWrapperView`가 채택해 `MainView`에 주입된다.
public protocol MainTabViewable where Self: View {
  init()
}
