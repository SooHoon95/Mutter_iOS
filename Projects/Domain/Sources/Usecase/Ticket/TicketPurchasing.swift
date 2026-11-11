import Foundation

/// 편지권 구매 계약. 구매 → 서버 검증(verify-purchase) → 지급까지 끝낸다.
/// 거래는 서버가 200을 준 뒤에만 마무리하고, 그 외에는 남겨 두었다가 `resendUnfinished`로 다시 보낸다.
public protocol TicketPurchasing {
  /// 상품별 스토어 표시 가격(현지 통화). 스토어에서 못 받은 상품은 빠진다.
  func displayPrices() async throws -> [TicketProductType: String]
  func purchase(_ product: TicketProductType) async throws -> TicketPurchaseResult
  /// 마무리되지 않은 거래를 서버에 다시 보낸다(앱 시작·로그인·편지권 화면 진입 때). 실패는 다음 기회로 미룬다.
  func resendUnfinished() async
}
