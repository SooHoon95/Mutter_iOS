import Foundation

/// 전달 유스케이스 구현. 접근 통제 로직은 RPC(서버 RLS)에서 강제된다.
public final class DeliveryUsecase: DeliveryUsecasable {
  private let repository: DeliveryRepositorable

  public init(repository: DeliveryRepositorable) {
    self.repository = repository
  }

  public func issue(letterId: String, password: String?, revealAt: Date?) async throws -> DeliveryLink {
    try await repository.issue(letterId: letterId, password: password, revealAt: revealAt)
  }

  public func revoke(token: String) async throws {
    try await repository.revoke(token: token)
  }

  public func links(letterId: String) async throws -> [DeliveryLink] {
    try await repository.links(letterId: letterId)
  }

  public func open(token: String, password: String?) async throws -> LetterPayload {
    try await repository.open(token: token, password: password)
  }
}
