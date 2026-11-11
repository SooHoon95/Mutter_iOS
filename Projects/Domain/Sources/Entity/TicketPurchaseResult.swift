import Foundation

/// 편지권 구매 결과.
public enum TicketPurchaseResult: Equatable {
  /// 서버가 검증·지급까지 마쳤다(지급 후 잔액).
  case completed(tickets: Int)
  /// 사용자가 결제를 취소했다 — 오류가 아니다.
  case cancelled
  /// 승인 대기(보호자 승인 등). 승인되면 거래 갱신 수신에서 지급된다.
  case pending
}
