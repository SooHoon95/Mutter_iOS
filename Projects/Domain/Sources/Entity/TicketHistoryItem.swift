import Foundation

/// 편지권 내역 한 줄(get_my_ticket_history, 최근 순).
public struct TicketHistoryItem: Equatable {
  public let createdAt: Date
  /// 증감(+구매·지급·환급 / −사용).
  public let delta: Int
  public let reason: TicketReasonType
  /// 사용·환급에 연결된 편지 제목(없으면 nil).
  public let letterTitle: String?

  public init(createdAt: Date, delta: Int, reason: TicketReasonType, letterTitle: String?) {
    self.createdAt = createdAt
    self.delta = delta
    self.reason = reason
    self.letterTitle = letterTitle
  }
}
