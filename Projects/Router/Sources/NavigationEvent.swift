import SwiftUI

/// 네비게이션 의도를 표현하는 이벤트(NavigationCoordinator 내부 전달용).
public enum NavigationEvent<Route: Hashable> {
  case push(Route)
  case pop
  case popTo(Route)
  case popToRoot
  case presentFullScreen(Route)
  case dismissFullScreen
}
