import Foundation

/// 받은함 항목 — 수신자가 보관한 편지(토큰으로 다시 열 수 있음).
public struct InboxItem: Identifiable, Equatable {
  public let letterId: String
  public let token: String
  public let title: String
  public let savedAt: Date

  public var id: String { token }

  public init(letterId: String, token: String, title: String, savedAt: Date) {
    self.letterId = letterId
    self.token = token
    self.title = title
    self.savedAt = savedAt
  }
}
