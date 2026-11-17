import SwiftUI

public extension View {
  /// 화면이 보일 때마다 GA4 `screen_view`를 남긴다(탭 전환·뒤로 돌아오기 포함 — UIKit 자동 기록과 같은 기준).
  /// SDK 자동 화면 기록은 SwiftUI에서 호스팅 컨트롤러 이름만 남겨 꺼 두었다(Info.plist).
  /// nil이면 아무것도 남기지 않는다(기록하지 않는 라우트용).
  func analyticsScreen(_ screen: AnalyticsScreen?) -> some View {
    onAppear {
      guard let screen else { return }
      AppAnalytics.logScreen(screen)
    }
  }
}
