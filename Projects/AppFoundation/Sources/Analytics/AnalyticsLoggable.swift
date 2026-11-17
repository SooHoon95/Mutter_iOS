import Foundation

/// 분석 기록기. 구현(Firebase)은 Infrastructure에 있고 앱 시작 때 `AppAnalytics.configure`로 붙인다.
public protocol AnalyticsLoggable: Sendable {
  func log(_ event: AnalyticsEvent)
  func logScreen(_ screen: AnalyticsScreen)
}
