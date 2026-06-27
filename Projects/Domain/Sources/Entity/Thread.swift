import Foundation

/// 편지 방향 — 스레드에서 내가 보낸 것/받은 것.
public enum LetterDirection: String, Equatable {
  case sent
  case received
}

/// 보낸 편지 + 받은 사람 요약(Home/Threads의 "보낸 편지" 표시용).
public struct SentLetterSummary: Identifiable, Equatable {
  public let letterId: String
  public let title: String
  public let sentAt: Date
  public let recipientId: String?
  public let recipientNickname: String?

  public var id: String { letterId }

  public init(
    letterId: String,
    title: String,
    sentAt: Date,
    recipientId: String?,
    recipientNickname: String?
  ) {
    self.letterId = letterId
    self.title = title
    self.sentAt = sentAt
    self.recipientId = recipientId
    self.recipientNickname = recipientNickname
  }
}

/// 스레드의 한 편지 — 상대와 주고받은 편지 한 통.
public struct ThreadLetter: Identifiable, Equatable {
  public let letterId: String
  public let direction: LetterDirection
  /// 받은 편지면 열람 토큰. 보낸 편지는 nil일 수 있음.
  public let token: String?
  public let title: String
  public let sentAt: Date

  public var id: String { letterId }

  public init(
    letterId: String,
    direction: LetterDirection,
    token: String?,
    title: String,
    sentAt: Date
  ) {
    self.letterId = letterId
    self.direction = direction
    self.token = token
    self.title = title
    self.sentAt = sentAt
  }
}
