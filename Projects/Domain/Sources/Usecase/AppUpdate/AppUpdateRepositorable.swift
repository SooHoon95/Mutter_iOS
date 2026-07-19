import Foundation

/// App Store 최신 버전 조회 추상화.
public protocol AppUpdateRepositorable {
  /// App Store에 게시된 최신 버전 문자열(예: "1.0.1"). 조회 실패/미게시면 nil.
  func latestAppStoreVersion() async throws -> String?
}
