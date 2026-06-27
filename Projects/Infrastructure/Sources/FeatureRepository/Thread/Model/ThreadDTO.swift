import Foundation

import Domain

/// get_counterparts RPC 반환 row.
struct CounterpartRow: Decodable {
  let counterpartId: String
  let nickname: String?
  let letterCount: Int

  enum CodingKeys: String, CodingKey {
    case nickname
    case counterpartId = "counterpart_id"
    case letterCount = "letter_count"
  }

  func toDomain() -> Counterpart {
    Counterpart(userId: counterpartId, nickname: nickname, exchangeCount: letterCount)
  }
}

/// get_thread RPC 반환 row.
struct ThreadLetterRow: Decodable {
  let letterId: String
  let token: String?
  let title: String
  let direction: String
  let at: Date

  enum CodingKeys: String, CodingKey {
    case token, title, direction, at
    case letterId = "letter_id"
  }

  func toDomain() -> ThreadLetter {
    ThreadLetter(
      letterId: letterId,
      direction: LetterDirection(rawValue: direction) ?? .sent,
      token: token,
      title: title,
      sentAt: at
    )
  }
}

/// get_my_sent_with_recipients RPC 반환 row.
struct SentWithRecipientRow: Decodable {
  let letterId: String
  let title: String
  let createdAt: Date
  let recipientId: String?
  let recipientNickname: String?

  enum CodingKeys: String, CodingKey {
    case title
    case letterId = "letter_id"
    case createdAt = "created_at"
    case recipientId = "recipient_id"
    case recipientNickname = "recipient_nickname"
  }

  func toDomain() -> SentLetterSummary {
    SentLetterSummary(
      letterId: letterId,
      title: title,
      sentAt: createdAt,
      recipientId: recipientId,
      recipientNickname: recipientNickname
    )
  }
}

/// get_thread RPC 파라미터.
struct ThreadParams: Encodable {
  let counterpart: String
  enum CodingKeys: String, CodingKey { case counterpart = "p_counterpart" }
}
