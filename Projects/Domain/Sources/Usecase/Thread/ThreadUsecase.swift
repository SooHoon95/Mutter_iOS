import Foundation

/// 스레드 유스케이스 구현.
public final class ThreadUsecase: ThreadUsecasable {
  private let repository: ThreadRepositorable

  public init(repository: ThreadRepositorable) {
    self.repository = repository
  }

  public func counterparts() async throws -> [Counterpart] {
    try await repository.counterparts()
  }

  public func thread(counterpartId: String) async throws -> [ThreadLetter] {
    try await repository.thread(counterpartId: counterpartId)
  }

  public func sentWithRecipients() async throws -> [SentLetterSummary] {
    try await repository.sentWithRecipients()
  }
}
