import Foundation

/// 연결 유스케이스 구현. 독점 1:1 불변식은 RPC(서버)에서 강제된다.
public final class ConnectionUsecase: ConnectionUsecasable {
  private let repository: ConnectionRepositorable

  public init(repository: ConnectionRepositorable) {
    self.repository = repository
  }

  public func createInvite() async throws -> String {
    try await repository.createInvite()
  }

  public func revokeInvite(token: String) async throws {
    try await repository.revokeInvite(token: token)
  }

  public func invite(token: String) async throws -> ConnectInvite {
    try await repository.invite(token: token)
  }

  public func accept(token: String) async throws {
    try await repository.accept(token: token)
  }

  public func myConnections() async throws -> [Connection] {
    try await repository.myConnections()
  }

  public func disconnect() async throws {
    try await repository.disconnect()
  }

  public func send(letterId: String, recipientId: String) async throws {
    try await repository.send(letterId: letterId, recipientId: recipientId)
  }
}
