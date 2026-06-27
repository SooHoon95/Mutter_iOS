import SwiftUI

/// 라우트를 화면으로 만드는 팩토리(Mercury 패턴).
/// 합성 루트(MutterApp)가 각 Feature의 Viewable 구현을 모아 이 프로토콜을 구현하고,
/// RouterView가 rootStack의 Route를 이 팩토리로 렌더한다 → Router/Feature는 서로의 View를 모른다.
public protocol ViewFactory {
  associatedtype ScreenRoute: Hashable
  associatedtype ViewType: View

  @ViewBuilder
  func makeView(_ route: ScreenRoute) -> ViewType
}
