import Foundation

/// 연결 데이터 접근 프로토콜(구현은 Infrastructure — *_connect_invite/send_to_connection/disconnect_connection RPC).
public protocol ConnectionRepositorable {
  func createInvite() async throws -> String
  /// 생성한 초대 링크를 무효화한다 (EC-2.8).
  func revokeInvite(token: String) async throws
  func invite(token: String) async throws -> ConnectInvite
  func accept(token: String) async throws
  func myConnections() async throws -> [Connection]
  func disconnect(otherUserId: String) async throws
  /// `permanent`가 true면 서버가 발송과 같은 트랜잭션에서 편지권 1장을 써 영구 편지로 만든다.
  func send(letterId: String, recipientId: String, permanent: Bool) async throws
}
