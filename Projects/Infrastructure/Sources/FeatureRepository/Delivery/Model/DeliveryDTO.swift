import Foundation

import Domain

/// issue_link RPC 파라미터. p_password/p_expires_at은 항상 전송(null 명시), p_reveal_at은 설정 시만.
/// PostgREST는 제공된 인자명 집합으로 함수를 매칭하므로 nil을 생략하면 함수를 못 찾는다 → 명시 인코딩.
struct IssueLinkParams: Encodable {
  let letterId: String
  let token: String
  let password: String?
  let expiresAt: String?
  let revealAt: String?

  enum CodingKeys: String, CodingKey {
    case letterId = "p_letter_id"
    case token = "p_token"
    case password = "p_password"
    case expiresAt = "p_expires_at"
    case revealAt = "p_reveal_at"
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(letterId, forKey: .letterId)
    try c.encode(token, forKey: .token)
    try c.encode(password, forKey: .password)     // null 명시
    try c.encode(expiresAt, forKey: .expiresAt)   // null 명시
    try c.encodeIfPresent(revealAt, forKey: .revealAt) // 설정 시만(서버 default)
  }
}

/// get_letter_by_token RPC 파라미터(p_token + p_password null 명시).
struct OpenLinkParams: Encodable {
  let token: String
  let password: String?

  enum CodingKeys: String, CodingKey {
    case token = "p_token"
    case password = "p_password"
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(token, forKey: .token)
    try c.encode(password, forKey: .password)
  }
}

/// 단일 토큰 파라미터(revoke_link/record_letter_open/save_to_inbox/*_connect_invite 공용).
struct TokenParam: Encodable {
  let token: String
  enum CodingKeys: String, CodingKey { case token = "p_token" }
}

/// issue_link RPC 반환 row(password_hash 포함 — hasPassword 판단용).
struct RpcDeliveryLinkRow: Decodable {
  let letterId: String
  let token: String
  let passwordHash: String?
  let expiresAt: Date?
  let revealAt: Date?
  let revoked: Bool

  enum CodingKeys: String, CodingKey {
    case token, revoked
    case letterId = "letter_id"
    case passwordHash = "password_hash"
    case expiresAt = "expires_at"
    case revealAt = "reveal_at"
  }

  func toDomain() -> DeliveryLink {
    DeliveryLink(
      token: token,
      letterId: letterId,
      hasPassword: passwordHash != nil,
      expiresAt: expiresAt,
      revealAt: revealAt,
      revoked: revoked
    )
  }
}

/// delivery_links 테이블 row(목록용 — has_password 생성 컬럼 사용, password_hash 비노출).
struct DeliveryLinkRow: Decodable {
  let letterId: String
  let token: String
  let hasPassword: Bool
  let expiresAt: Date?
  let revealAt: Date?
  let revoked: Bool

  enum CodingKeys: String, CodingKey {
    case token, revoked
    case letterId = "letter_id"
    case hasPassword = "has_password"
    case expiresAt = "expires_at"
    case revealAt = "reveal_at"
  }

  func toDomain() -> DeliveryLink {
    DeliveryLink(
      token: token,
      letterId: letterId,
      hasPassword: hasPassword,
      expiresAt: expiresAt,
      revealAt: revealAt,
      revoked: revoked
    )
  }
}

/// get_letter_by_token RPC 반환(수신 페이로드). cues는 paragraphs[0].cue로 평탄화.
struct LetterPayloadDTO: Decodable {
  let id: String
  let title: String
  let paragraphs: [ParagraphDTO]
  let templateId: String
  let audioDisabled: Bool

  enum CodingKeys: String, CodingKey {
    case id, title, paragraphs
    case templateId = "template_id"
    case audioDisabled = "audio_disabled"
  }

  func toDomain() -> LetterPayload {
    LetterPayload(
      id: id,
      title: title,
      body: LetterContentCodec.body(from: paragraphs),
      templateId: templateId,
      cue: LetterContentCodec.cue(from: paragraphs),
      audioDisabled: audioDisabled
    )
  }
}
