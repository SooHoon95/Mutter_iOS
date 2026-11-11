import Foundation

/// 편지권 구매 계약. 구매 → 서버 검증(verify-purchase) → 지급까지 끝내고 지급 후 잔액을 돌려준다.
/// 실제 스토어 연동은 다음 작업(I5)이고, 그 전까지는 "구매 불가"를 던지는 구현이 주입된다.
public protocol TicketPurchasing {
  func purchase(_ product: TicketProductType) async throws -> Int
}
