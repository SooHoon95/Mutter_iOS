import Foundation

/// 테이크다운 데이터 접근 프로토콜(구현은 Infrastructure — report_takedown RPC).
public protocol TakedownRepositorable {
  func report(
    letterId: String?,
    trackRef: String?,
    claimant: String,
    contact: String,
    reason: String
  ) async throws
}
