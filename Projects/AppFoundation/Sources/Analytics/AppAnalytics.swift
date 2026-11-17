import Foundation

/// 분석 기록 진입점. ModelData·View는 `AppAnalytics.log(...)`만 부른다.
///
/// `MutterContainer` 대신 기본값이 no-op인 전역을 쓰는 이유: 컨테이너는 미등록 resolve에서 crash한다.
/// Feature SampleApp·테스트는 분석기를 등록하지 않으므로, 기록이 화면 동작을 막지 않게 연결 전에는 조용히 버린다.
/// (웹 `src/lib/analytics.ts`의 `setAnalyticsSink`/`track`과 같은 모양.)
public enum AppAnalytics {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var logger: AnalyticsLoggable?

  /// 앱 시작 때 한 번(Firebase 초기화 뒤) 호출한다.
  public static func configure(_ logger: AnalyticsLoggable) {
    lock.lock(); defer { lock.unlock() }
    self.logger = logger
  }

  public static func log(_ event: AnalyticsEvent) {
    current?.log(event)
  }

  public static func logScreen(_ screen: AnalyticsScreen) {
    current?.logScreen(screen)
  }

  private static var current: AnalyticsLoggable? {
    lock.lock(); defer { lock.unlock() }
    return logger
  }
}
