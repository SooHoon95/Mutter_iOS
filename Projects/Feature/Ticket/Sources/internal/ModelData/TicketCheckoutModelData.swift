import Foundation

import AppFoundation
import Domain
import Router
import UIComponent

/// 결제 안내 시트 — 편지권이 없는 계정이 영구 편지로 보내거나 받은 편지를 간직하려 할 때.
/// 상품을 골라 사고, 산 편지권으로 하려던 일(영구 전환·간직)까지 이어서 마친다.
@MainActor
@Observable
final class TicketCheckoutModelData {
  let route: TicketCheckoutRoute
  /// 고를 수 있는 상품(1장·5장).
  let products: [TicketProductType] = [.one, .five]
  var selectedProduct: TicketProductType = .one

  private(set) var entitlements: Entitlements?
  /// 스토어 표시 가격. 비어 있으면(로드 전·실패) 살 수 없다.
  private(set) var prices: [TicketProductType: String] = [:]
  private(set) var isLoading = true
  /// 구매하거나 편지권을 쓰는 중 — 버튼 로딩, 시트 닫기 막기.
  private(set) var isWorking = false
  /// 편지권 사용까지 끝났다 → 화면이 닫히며 호출한 쪽에 알린다.
  private(set) var isDone = false
  var errorMessage: String?

  private let ticketUsecase: TicketUsecasable
  private let purchaser: TicketPurchasing

  init(route: TicketCheckoutRoute, ticketUsecase: TicketUsecasable, purchaser: TicketPurchasing) {
    self.route = route
    self.ticketUsecase = ticketUsecase
    self.purchaser = purchaser
  }

  var tickets: Int { entitlements?.tickets ?? 0 }

  /// 지금 가진 편지권으로 바로 할 수 있는지(관리자는 차감 없음). 구매 직후나, 시트가 뜨는 사이 잔액이 생긴 경우.
  var canUseNow: Bool {
    guard let entitlements else { return false }
    return entitlements.tickets > 0 || entitlements.isAdmin
  }

  var canConfirm: Bool {
    guard !isLoading, !isWorking else { return false }
    return canUseNow || prices[selectedProduct] != nil
  }

  /// 시트가 뜰 때 — 끝내지 못한 거래를 먼저 서버에 보내(잔액 반영) 뒤 잔액과 가격을 받는다.
  func appear() async {
    isLoading = true
    defer { isLoading = false }
    await purchaser.resendUnfinished()
    async let pricesTask = purchaser.displayPrices()
    entitlements = try? await ticketUsecase.entitlements()
    prices = (try? await pricesTask) ?? [:]
    if !canUseNow && prices.isEmpty {
      errorMessage = MutterError(.purchaseUnavailable).userMessage
    }
  }

  /// 맨 아래 버튼 — 편지권이 없으면 고른 상품을 사고, 이어서 편지권 1장으로 하려던 일을 한다.
  func confirm() async {
    guard canConfirm else { return }
    isWorking = true
    errorMessage = nil
    defer { isWorking = false }
    do {
      if !canUseNow {
        switch try await purchaser.purchase(selectedProduct) {
        case .completed:
          entitlements = try? await ticketUsecase.entitlements()
        case .pending:
          errorMessage = L10n.ticketPending
          return
        case .cancelled:
          return
        }
      }
      try await useTicket()
      isDone = true
    } catch {
      // 구매는 됐는데 사용이 실패했으면 편지권은 남아 있다 — 잔액을 다시 받아 버튼을 "편지권 1장으로 …"로 바꾼다.
      entitlements = (try? await ticketUsecase.entitlements()) ?? entitlements
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }

  private func useTicket() async throws {
    switch route {
    case .sendPermanent(let letterId):
      try await ticketUsecase.makePermanent(letterId: letterId)
    case .keepReceived(let token, let password):
      try await ticketUsecase.keepReceived(token: token, password: password)
    }
  }
}
