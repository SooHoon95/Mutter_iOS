import Foundation

/// 받은함 유스케이스 구현.
public final class InboxUsecase: InboxUsecasable {
  private let repository: InboxRepositorable

  public init(repository: InboxRepositorable) {
    self.repository = repository
  }

  public func save(token: String) async throws {
    try await repository.save(token: token)
  }

  public func myInbox() async throws -> [InboxItem] {
    try await repository.myInbox()
  }
}
