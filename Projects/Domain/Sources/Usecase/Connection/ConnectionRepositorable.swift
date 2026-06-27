import Foundation

/// 연결 데이터 접근 프로토콜(구현은 Infrastructure — *_connect_invite/send_to_connection/disconnect_connection RPC).
public protocol ConnectionRepositorable {
  func createInvite() async throws -> String
  func invite(token: String) async throws -> ConnectInvite
  func accept(token: String) async throws
  func myConnections() async throws -> [Connection]
  func disconnect() async throws
  func send(letterId: String, recipientId: String) async throws
}
