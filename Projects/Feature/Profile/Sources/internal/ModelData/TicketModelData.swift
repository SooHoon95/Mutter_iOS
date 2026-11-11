import Foundation

import AppFoundation
import Domain
import UIComponent

/// 편지권 화면 — 잔액·내역·상품 구매. 구매는 `TicketPurchasing`에 맡긴다(스토어 연동 전엔 "구매 불가").
@MainActor
@Observable
final class TicketModelData {
  /// 화면에 보일 상품(1장·5장).
  let products: [TicketProductType] = [.one, .five]

  private(set) var entitlements: Entitlements?
  private(set) var history: [TicketHistoryItem] = []
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
      _ = try await purchaser.purchase(product)
      await load()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }
}
