import Foundation

/// 전달 링크(capability link) — 추측불가 토큰 + 암호 기본 ON + 만료/예약공개/revoke.
public struct DeliveryLink: Identifiable, Equatable {
  /// ≥128bit 추측불가 토큰. 이 자체가 식별자.
  public let token: String
  public let letterId: String
  public let hasPassword: Bool
  public let expiresAt: Date?
  /// 예약공개 — 이 시각 이후에만 열린다. nil이면 즉시 공개.
  public let revealAt: Date?
  public let revoked: Bool

  public var id: String { token }

  public init(
    token: String,
    letterId: String,
    hasPassword: Bool,
    expiresAt: Date? = nil,
    revealAt: Date? = nil,
    revoked: Bool = false
  ) {
    self.token = token
    self.letterId = letterId
    self.hasPassword = hasPassword
    self.expiresAt = expiresAt
    self.revealAt = revealAt
    self.revoked = revoked
  }
}

/// 읽음확인 롤업(발신자용) — 한 편지가 몇 번/언제 열렸는지.
public struct LetterOpenSummary: Identifiable, Equatable {
  public let letterId: String
  public let openCount: Int
  public let lastOpenedAt: Date

  public var id: String { letterId }

  public init(letterId: String, openCount: Int, lastOpenedAt: Date) {
    self.letterId = letterId
    self.openCount = openCount
    self.lastOpenedAt = lastOpenedAt
  }
}
