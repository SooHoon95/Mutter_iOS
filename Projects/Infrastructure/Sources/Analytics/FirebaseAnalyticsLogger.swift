import Foundation

import FirebaseAnalytics

import AppFoundation

/// Firebase Analytics(앱용 GA4)로 보내는 기록기. `FirebaseApp.configure()` 뒤에 `AppAnalytics.configure`로 붙인다.
public struct FirebaseAnalyticsLogger: AnalyticsLoggable {
  public init() {}

  public func log(_ event: AnalyticsEvent) {
    let parameters = event.parameters
    Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
  }

  /// 자동 화면 기록을 껐으므로 직접 보낸다. screen_class는 화면 이름과 같게 둔다(호스팅 컨트롤러 이름 대신).
  public func logScreen(_ screen: AnalyticsScreen) {
    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
      AnalyticsParameterScreenName: screen.rawValue,
      AnalyticsParameterScreenClass: screen.rawValue
    ])
  }
}
