import Foundation

/// 보낸 편지의 간직 요청자(get_letter_keep_requests 한 행, 요청한 순).
public struct LetterKeepRequest: Identifiable, Equatable {
  public let userId: String
  /// nil이면 화면에서 "이름 없는 사용자".
  public let nickname: String?
  public let requestedAt: Date

  public var id: String { userId }

  public init(userId: String, nickname: String?, requestedAt: Date) {
    self.userId = userId
    self.nickname = nickname
    self.requestedAt = requestedAt
  }
}
