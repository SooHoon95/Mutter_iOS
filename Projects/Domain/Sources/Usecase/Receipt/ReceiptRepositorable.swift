import Foundation

/// 읽음확인 데이터 접근 프로토콜(구현은 Infrastructure — record_letter_open/get_my_letter_opens RPC).
public protocol ReceiptRepositorable {
  func recordOpen(token: String) async throws
  func myLetterOpens() async throws -> [LetterOpenSummary]
}
