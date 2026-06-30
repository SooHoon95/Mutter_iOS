import SwiftUI

/// MainTab 단독 실행 샘플.
/// `MainTabView`는 Router `*Viewable` 제네릭으로 탭 콘텐츠를 주입받으므로,
/// 실제 탭 조립은 합성 루트(MutterApp)의 ViewWrapper에서 이뤄진다. 여기선 안내 플레이스홀더만 표시한다.
@main
struct MainTabSampleApp: App {
  var body: some Scene {
    WindowGroup {
      Text("MainTab은 합성 루트(MutterApp)에서 ViewWrapper로 조립됩니다.")
        .multilineTextAlignment(.center)
        .padding()
    }
  }
}
