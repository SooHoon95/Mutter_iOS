import Foundation

/// 보낸 편지의 열람자(get_letter_readers 한 행, 처음 연 순).
public struct LetterReader: Identifiable, Equatable {
  public let userId: String
  /// nil이면 화면에서 "이름 없는 사용자".
  public let nickname: String?
  public let firstOpenedAt: Date
  public let lastOpenedAt: Date
  public let openCount: Int

  public var id: String { userId }

  public init(userId: String, nickname: String?, firstOpenedAt: Date, lastOpenedAt: Date, openCount: Int) {
    self.userId = userId
    self.nickname = nickname
    self.firstOpenedAt = firstOpenedAt
    self.lastOpenedAt = lastOpenedAt
    self.openCount = openCount
  }
}
