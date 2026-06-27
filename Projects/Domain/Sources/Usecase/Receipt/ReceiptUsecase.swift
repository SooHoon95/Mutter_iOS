import Foundation

/// 읽음확인 유스케이스 구현.
public final class ReceiptUsecase: ReceiptUsecasable {
  private let repository: ReceiptRepositorable

  public init(repository: ReceiptRepositorable) {
    self.repository = repository
  }

  public func recordOpen(token: String) async throws {
    try await repository.recordOpen(token: token)
  }

  public func myLetterOpens() async throws -> [LetterOpenSummary] {
    try await repository.myLetterOpens()
  }
}
