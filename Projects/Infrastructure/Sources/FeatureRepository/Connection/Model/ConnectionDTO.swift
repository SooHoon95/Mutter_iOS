import Foundation

import Domain

/// get_connect_invite RPC 반환 row(독점 1:1 필드는 구 시그니처 대비 optional → false 폴백).
struct ConnectInviteRow: Decodable {
  let inviterId: String
  let inviterNickname: String?
  let isSelf: Bool
  let alreadyConnected: Bool
  let viewerHasConnection: Bool?
  let inviterHasConnection: Bool?

  enum CodingKeys: String, CodingKey {
    case inviterId = "inviter_id"
    case inviterNickname = "inviter_nickname"
    case isSelf = "is_self"
    case alreadyConnected = "already_connected"
    case viewerHasConnection = "viewer_has_connection"
    case inviterHasConnection = "inviter_has_connection"
  }

  func toDomain() -> ConnectInvite {
    ConnectInvite(
      inviterId: inviterId,
      inviterNickname: inviterNickname,
      isSelf: isSelf,
      alreadyConnected: alreadyConnected,
      viewerHasConnection: viewerHasConnection ?? false,
      inviterHasConnection: inviterHasConnection ?? false
    )
  }
}

/// get_my_connections RPC 반환 row.
struct ConnectionRow: Decodable {
  let userId: String
  let nickname: String?
  let connectedAt: Date

  enum CodingKeys: String, CodingKey {
    case nickname
    case userId = "user_id"
    case connectedAt = "connected_at"
  }

  func toDomain() -> Connection {
    Connection(userId: userId, nickname: nickname, connectedAt: connectedAt)
  }
}

/// send_to_connection RPC 파라미터(토큰은 구현부 생성).
struct SendToConnectionParams: Encodable {
  let letterId: String
  let recipient: String
  let token: String

  enum CodingKeys: String, CodingKey {
    case letterId = "p_letter_id"
    case recipient = "p_recipient"
    case token = "p_token"
  }
}

/// disconnect_connection RPC 파라미터 — 해제할 상대(N:N이라 대상 지정 필수).
struct DisconnectParams: Encodable {
  let otherUser: String

  enum CodingKeys: String, CodingKey {
    case otherUser = "p_other_user"
  }
}
