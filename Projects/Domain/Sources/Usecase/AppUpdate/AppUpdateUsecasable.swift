import Foundation

/// 강제 업데이트 필요 여부 판단 유스케이스.
public protocol AppUpdateUsecasable {
  /// 설치 버전이 App Store 최신 버전보다 낮으면 true(강제 업데이트 필요).
  /// 조회 불확실(네트워크 실패 등)일 땐 false — 앱을 잠그지 않는다(fail-open).
  func isUpdateRequired(currentVersion: String) async -> Bool
}
