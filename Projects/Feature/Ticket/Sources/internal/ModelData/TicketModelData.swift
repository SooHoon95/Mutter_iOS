import Foundation

import AppFoundation
import Domain
import UIComponent

/// 편지권 화면 — 잔액·내역·상품 구매. 구매·서버 검증·거래 마무리는 `TicketPurchasing`에 맡긴다.
@MainActor
@Observable
final class TicketModelData {
  /// 화면에 보일 상품(1장·5장).
  let products: [TicketProductType] = [.one, .five]

  private(set) var entitlements: Entitlements?
  private(set) var history: [TicketHistoryItem] = []
  /// 스토어 표시 가격. 비어 있으면(로드 전·실패) 구매 버튼을 끈다.
  private(set) var prices: [TicketProductType: String] = [:]
  var isLoading = false
  /// 구매 중인 상품(중복 탭 방지 + 버튼 로딩 표시).
  var purchasingProduct: TicketProductType?
  var errorMessage: String?

  private let ticketUsecase: TicketUsecasable
  private let purchaser: TicketPurchasing

  init(ticketUsecase: TicketUsecasable, purchaser: TicketPurchasing) {
    self.ticketUsecase = ticketUsecase
    self.purchaser = purchaser
  }

  var tickets: Int { entitlements?.tickets ?? 0 }
  var showsPurchaseUI: Bool { entitlements?.showsPurchaseUI ?? false }

  /// 상품 버튼을 누를 수 있는지 — 로딩·구매 중이 아니고 스토어 가격을 받은 상품만.
  func canPurchase(_ product: TicketProductType) -> Bool {
    !isLoading && purchasingProduct == nil && prices[product] != nil
  }

  /// 화면 진입 — 남은 거래를 먼저 서버에 보내(잔액 반영) 뒤 잔액·내역·가격을 받는다.
  func appear() async {
    isLoading = true
    await purchaser.resendUnfinished()
    async let pricesTask = purchaser.displayPrices()
    await load()
    prices = (try? await pricesTask) ?? [:]
    // 스토어 상품을 못 받으면 버튼이 꺼진 채 이유가 안 보인다 — 살 수 없는 상태임을 알린다.
    if prices.isEmpty && showsPurchaseUI && errorMessage == nil {
      errorMessage = MutterError(.purchaseUnavailable).userMessage
    }
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    async let entitlementsTask = ticketUsecase.entitlements()
    async let historyTask = ticketUsecase.history()
    entitlements = try? await entitlementsTask
    history = (try? await historyTask) ?? []
  }

  func purchase(_ product: TicketProductType) async {
    guard purchasingProduct == nil else { return }
    purchasingProduct = product
    errorMessage = nil
    defer { purchasingProduct = nil }
    do {
      switch try await purchaser.purchase(product) {
      case .completed:
        await load()
      case .pending:
        errorMessage = L10n.ticketPending
      case .cancelled:
        break
      }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }
}
