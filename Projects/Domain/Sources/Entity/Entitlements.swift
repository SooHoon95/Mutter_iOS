import Foundation

/// 내 권한·편지권(get_my_entitlements). 기간 일수는 서버 설정값이다 — 코드에 14·30을 박지 않는다.
public struct Entitlements: Equatable {
  public let isAdmin: Bool
  /// 편지권 잔액.
  public let tickets: Int
  /// 유료 규칙 스위치.
  public let paidEnabled: Bool
  /// 무료 열람 기간(일).
  public let freeDays: Int
  /// 잠긴 뒤 삭제까지 유예(일).
  public let graceDays: Int

  public init(isAdmin: Bool, tickets: Int, paidEnabled: Bool, freeDays: Int, graceDays: Int) {
    self.isAdmin = isAdmin
    self.tickets = tickets
    self.paidEnabled = paidEnabled
    self.freeDays = freeDays
    self.graceDays = graceDays
  }

  /// 편지권 관련 UI(프로필 항목·"영구 편지로 만들기"·"영구" 표시)를 보일지.
  /// 스위치가 꺼져 있고 관리자도 아니면 전부 숨긴다.
  public var showsTicketUI: Bool { paidEnabled || isAdmin }

  /// 구매 UI를 보일지 — 관리자는 차감 없이 영구가 되므로 구매 UI를 숨긴다.
  public var showsPurchaseUI: Bool { paidEnabled && !isAdmin }
}
