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
///
/// 관대한 디코딩: 예전엔 `title`·`direction`·`at`가 non-optional이라 그중 하나가 NULL이거나
/// 서버 반환 키가 미세하게 어긋나면 **단 한 건의 디코드 실패가 스레드 전체를 `[]`로 만들었다**(빈 시트 원인).
/// 필드별로 기본값을 둬 편지가 목록에서 통째로 빠지지 않게 한다.
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

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // 각 필드는 누락/NULL이어도 실패하지 않고 안전한 기본값으로 대체한다.
    letterId = (try? container.decode(String.self, forKey: .letterId)) ?? ""
    token = try? container.decode(String.self, forKey: .token)
    title = (try? container.decode(String.self, forKey: .title)) ?? ""
    direction = (try? container.decode(String.self, forKey: .direction)) ?? LetterDirection.sent.rawValue
    at = (try? container.decode(Date.self, forKey: .at)) ?? Date()
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
