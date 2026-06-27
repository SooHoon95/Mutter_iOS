import Foundation

/// 테이크다운 유스케이스 — 저작권/신고 채널(라이선스 안전).
public protocol TakedownUsecasable {
  /// 신고 접수. letterId/trackRef 중 해당하는 대상을 지정.
  func report(
    letterId: String?,
    trackRef: String?,
    claimant: String,
    contact: String,
    reason: String
  ) async throws
}
