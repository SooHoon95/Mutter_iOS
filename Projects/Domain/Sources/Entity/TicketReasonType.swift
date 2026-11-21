import Foundation

/// 편지권 내역 사유(서버 `reason`). 모르는 값은 `unknown`으로 받아 화면이 깨지지 않게 한다.
public enum TicketReasonType: String, Equatable {
  case purchase
  case use
  case grant
  case refund
  /// 가입 선물(계정을 만들 때 서버가 자동으로 준 편지권).
  case welcome
  case unknown
}
