import Foundation

/// 편지권 유스케이스 구현. 잔액·차감·환급은 서버가 단독으로 강제한다.
public final class TicketUsecase: TicketUsecasable {
  private let repository: TicketRepositorable

  public init(repository: TicketRepositorable) {
    self.repository = repository
  }

  public func entitlements() async throws -> Entitlements {
    try await repository.entitlements()
  }

  public func history() async throws -> [TicketHistoryItem] {
    try await repository.history()
  }

  public func makePermanent(letterId: String) async throws {
    try await repository.makePermanent(letterId: letterId)
  }

  public func keepReceived(token: String, password: String?) async throws {
    try await repository.keepReceived(token: token, password: password)
  }
}
