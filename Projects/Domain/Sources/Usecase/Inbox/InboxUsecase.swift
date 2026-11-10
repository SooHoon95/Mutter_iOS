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

  public func remove(letterIds: [String]) async throws {
    guard !letterIds.isEmpty else { return }
    try await repository.remove(letterIds: letterIds)
  }

  public func deletedInbox() async throws -> [DeletedInboxItem] {
    try await repository.deletedInbox()
  }

  @discardableResult
  public func restore(letterIds: [String]) async throws -> Int {
    guard !letterIds.isEmpty else { return 0 }
    return try await repository.restore(letterIds: letterIds)
  }

  @discardableResult
  public func purge(letterIds: [String]) async throws -> Int {
    guard !letterIds.isEmpty else { return 0 }
    return try await repository.purge(letterIds: letterIds)
  }
}
