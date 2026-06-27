import Foundation

/// 스레드 유스케이스 — 상대별 주고받음 + 보낸 편지 요약(답장은 Compose가 send 재사용).
public protocol ThreadUsecasable {
  func counterparts() async throws -> [Counterpart]
  func thread(counterpartId: String) async throws -> [ThreadLetter]
  func sentWithRecipients() async throws -> [SentLetterSummary]
}
