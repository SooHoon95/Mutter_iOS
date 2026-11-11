import Foundation

import Domain

/// get_letter_access_states RPC 반환 row.
struct LetterAccessStateRow: Decodable {
  let letterId: String
  let state: String
  let accessUntil: Date?
  let deleteAt: Date?
  /// 나중에 더해진 키 — 없으면 false.
  let keptByRecipient: Bool?

  enum CodingKeys: String, CodingKey {
    case state
    case letterId = "letter_id"
    case accessUntil = "access_until"
    case deleteAt = "delete_at"
    case keptByRecipient = "kept_by_recipient"
  }

  /// 모르는 state는 nil — 목록에 아무것도 붙이지 않는다(지금과 같은 표시).
  func toDomain() -> LetterAccessState? {
    guard let type = LetterAccessType(rawValue: state) else { return nil }
    return LetterAccessState(
      letterId: letterId,
      type: type,
      accessUntil: accessUntil,
      deleteAt: deleteAt,
      keptByRecipient: keptByRecipient ?? false
    )
  }
}

/// get_letter_cover RPC 반환. sealed면 나머지 키가 없다.
struct LetterCoverDTO: Decodable {
  let sealed: Bool
  let templateId: String?
  let title: String?
  let senderNickname: String?
  let state: String?
  let accessUntil: Date?
  let deleteAt: Date?
  let loginRequired: Bool?

  enum CodingKeys: String, CodingKey {
    case sealed, title, state
    case templateId = "template_id"
    case senderNickname = "sender_nickname"
    case accessUntil = "access_until"
    case deleteAt = "delete_at"
    case loginRequired = "login_required"
  }

  func toDomain() -> LetterCover {
    guard !sealed else { return .sealed }
    return LetterCover(
      isSealed: false,
      templateId: templateId,
      title: title,
      senderNickname: senderNickname,
      accessType: state.flatMap(LetterAccessType.init(rawValue:)),
      accessUntil: accessUntil,
      deleteAt: deleteAt,
      loginRequired: loginRequired ?? false
    )
  }
}

/// get_letter_readers RPC 반환 row.
struct LetterReaderRow: Decodable {
  let userId: String
  let nickname: String?
  let firstOpenedAt: Date
  let lastOpenedAt: Date
  let openCount: Int

  enum CodingKeys: String, CodingKey {
    case nickname
    case userId = "user_id"
    case firstOpenedAt = "first_opened_at"
    case lastOpenedAt = "last_opened_at"
    case openCount = "open_count"
  }

  func toDomain() -> LetterReader {
    LetterReader(
      userId: userId,
      nickname: nickname,
      firstOpenedAt: firstOpenedAt,
      lastOpenedAt: lastOpenedAt,
      openCount: openCount
    )
  }
}

/// `duplicate-letter` 요청 `{ letterId }`(사용자 JWT는 SDK가 Authorization에 싣는다).
struct DuplicateLetterRequest: Encodable {
  let letterId: String
}

/// `duplicate-letter` 응답 `{ letterId: <새 편지 uuid> }`.
struct DuplicateLetterResponse: Decodable {
  let letterId: String
}
