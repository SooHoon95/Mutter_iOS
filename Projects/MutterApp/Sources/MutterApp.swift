import SwiftUI

/// 앱 진입점(합성 루트). 의존성 그래프를 1회 구성하고 RootView에 주입한다.
@main
struct MutterApp: App {
  @State private var dependencies = AppDependencies()

  var body: some Scene {
    WindowGroup {
      RootView(deps: dependencies)
    }
  }
}
