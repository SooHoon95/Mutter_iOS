import Foundation

/// 읽음확인 유스케이스 — 수신자 ▶ 기록 + 발신자 롤업.
public protocol ReceiptUsecasable {
  /// 수신자가 편지를 열 때(▶) 호출. 무계정도 가능.
  func recordOpen(token: String) async throws
  /// 발신자용 읽음 롤업.
  func myLetterOpens() async throws -> [LetterOpenSummary]
}
