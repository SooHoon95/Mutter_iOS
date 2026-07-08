import Foundation

/// 연결 유스케이스 — 독점 1:1 연결(초대·수락·해제) + 연결 상대에게 발송.
public protocol ConnectionUsecasable {
  /// 초대 토큰 생성 → 공유용 토큰 반환.
  func createInvite() async throws -> String
  /// 생성한 초대 링크를 무효화한다 (EC-2.8).
  func revokeInvite(token: String) async throws
  /// 초대 미리보기(수락 가능 여부 판단).
  func invite(token: String) async throws -> ConnectInvite
  /// 초대 수락(양쪽 미연결일 때만 — 서버에서 강제).
  func accept(token: String) async throws
  func myConnections() async throws -> [Connection]
  /// 연결 해제(특정 상대 — 편지·받은함은 보존). N:N이라 대상 지정 필수.
  func disconnect(otherUserId: String) async throws
  /// 연결된 상대에게 편지 발송(전달 토큰은 구현부에서 생성).
  func send(letterId: String, recipientId: String) async throws
}
