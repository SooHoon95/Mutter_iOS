import Foundation

/// 편지권 내역 사유(서버 `reason`). 모르는 값은 `unknown`으로 받아 화면이 깨지지 않게 한다.
public enum TicketReasonType: String, Equatable {
  case purchase
  case use
  case grant
  case refund
  case unknown
}
