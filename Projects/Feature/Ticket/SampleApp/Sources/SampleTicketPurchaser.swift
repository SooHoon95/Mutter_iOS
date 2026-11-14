import Foundation

import Domain

/// 샘플 앱용 구매자 — 가격만 보여 주고 구매는 취소로 돌려준다.
struct SampleTicketPurchaser: TicketPurchasing {
  func displayPrices() async throws -> [TicketProductType: String] {
    [.one: "₩1,100", .five: "₩4,400"]
  }

  func purchase(_ product: TicketProductType) async throws -> TicketPurchaseResult { .cancelled }
  func resendUnfinished() async {}
}
