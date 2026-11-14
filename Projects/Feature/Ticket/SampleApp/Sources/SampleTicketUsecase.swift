import Foundation

import Domain

/// 샘플 앱용 편지권 유스케이스 — 정해 둔 잔액만 돌려준다.
struct SampleTicketUsecase: TicketUsecasable {
  let tickets: Int

  func entitlements() async throws -> Entitlements {
    Entitlements(isAdmin: false, tickets: tickets, paidEnabled: true, freeDays: 7, graceDays: 30)
  }

  func history() async throws -> [TicketHistoryItem] { [] }
  func makePermanent(letterId: String) async throws {}
  func keepReceived(token: String, password: String?) async throws {}
}
