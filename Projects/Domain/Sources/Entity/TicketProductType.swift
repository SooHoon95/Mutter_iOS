import Foundation

/// 편지권 상품(소모성). 상품 id는 스토어·서버(verify-purchase)와 같은 계약이다.
public enum TicketProductType: String, Equatable {
  case one = "mutter.ticket.1"
  case five = "mutter.ticket.5"

  /// 지급 장수.
  public var ticketCount: Int {
    switch self {
    case .one: return 1
    case .five: return 5
    }
  }

  public var productId: String { rawValue }
}
