import Foundation

/// 스레드 데이터 접근 프로토콜(구현은 Infrastructure — get_counterparts/get_thread/get_my_sent_with_recipients RPC).
public protocol ThreadRepositorable {
  func counterparts() async throws -> [Counterpart]
  func thread(counterpartId: String) async throws -> [ThreadLetter]
  func sentWithRecipients() async throws -> [SentLetterSummary]
}
