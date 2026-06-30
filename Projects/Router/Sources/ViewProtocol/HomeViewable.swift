import SwiftUI

/// 홈 탭 화면 계약(Mercury `*Viewable` 패턴). 합성 루트의 ViewWrapper가 채택해
/// `MainTabView`에 무인자 생성(`init()`)으로 주입된다 — Feature→Feature 의존 0.
public protocol HomeViewable where Self: View {
  init()
}
