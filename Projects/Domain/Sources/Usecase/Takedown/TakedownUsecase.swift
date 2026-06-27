import Foundation

/// 테이크다운 유스케이스 구현.
public final class TakedownUsecase: TakedownUsecasable {
  private let repository: TakedownRepositorable

  public init(repository: TakedownRepositorable) {
    self.repository = repository
  }

  public func report(
    letterId: String?,
    trackRef: String?,
    claimant: String,
    contact: String,
    reason: String
  ) async throws {
    try await repository.report(
      letterId: letterId,
      trackRef: trackRef,
      claimant: claimant,
      contact: contact,
      reason: reason
    )
  }
}
