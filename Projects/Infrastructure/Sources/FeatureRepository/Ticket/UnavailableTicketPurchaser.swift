import Foundation

import AppFoundation
import Domain

/// 스토어 연동(I5) 전의 `TicketPurchasing` 구현 — 항상 "구매 불가"를 던진다.
/// StoreKit 구현이 생기면 호출부 주입만 그것으로 바꾼다.
public final class UnavailableTicketPurchaser: TicketPurchasing {
  public init() {}

  public func purchase(_ product: TicketProductType) async throws -> Int {
    throw MutterError(.purchaseUnavailable)
  }
}
