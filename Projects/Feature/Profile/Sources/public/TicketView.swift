import SwiftUI

import Domain
import UIComponent

/// 편지권 화면(프로필 → 편지권) — 잔액·설명·상품(1장·5장)·내역.
/// 구매 UI는 유료 스위치가 켜진 일반 계정에만 보인다(관리자는 차감 없이 영구가 되므로 숨김).
public struct TicketView: View {
  @State private var model: TicketModelData
  private let closesAfterPurchase: Bool
  private let onBack: () -> Void

  /// - Parameter closesAfterPurchase: 영구 편지를 보내려다 들어온 구매 화면이면 true —
  ///   왜 왔는지 한 줄로 알리고, 내역은 숨기고, 구매가 끝나면 스스로 닫혀 보내기로 돌아간다.
  public init(
    ticketUsecase: TicketUsecasable,
    purchaser: TicketPurchasing,
    closesAfterPurchase: Bool = false,
    onBack: @escaping () -> Void
  ) {
    _model = State(initialValue: TicketModelData(ticketUsecase: ticketUsecase, purchaser: purchaser))
    self.closesAfterPurchase = closesAfterPurchase
    self.onBack = onBack
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          L10n.ticketTitle,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            balanceCard

            if closesAfterPurchase {
              Text(L10n.ticketNeededForPermanent)
                .fonts(.bodyMediumBold)
                .foregroundStyle(Asset.Colors.ink.color)
            }

            if model.showsPurchaseUI {
              VStack(spacing: 8) {
                ForEach(model.products, id: \.self) { product in
                  MutterButton(
                    model.prices[product].map { L10n.ticketProductPrice(product.ticketCount, $0) }
                      ?? L10n.ticketProduct(product.ticketCount),
                    style: product == .one ? .secondary : .primary,
                    isLoading: model.purchasingProduct == product,
                    isEnabled: model.canPurchase(product)
                  ) {
                    Task { await model.purchase(product) }
                  }
                }
              }
            }

            if let message = model.errorMessage {
              Text(message).fonts(.caption).foregroundStyle(Asset.Colors.danger.color)
            }

            if !closesAfterPurchase { historySection }
          }
          .padding(24)
          .frame(maxWidth: 560)
        }
        .refreshable { await model.load() }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task { await model.appear() }
    .onChange(of: model.purchaseCount) {
      if closesAfterPurchase { onBack() }
    }
  }

  // MARK: - 잔액 카드

  private var balanceCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.tickets > 0 ? L10n.ticketBalance(model.tickets) : L10n.ticketNone)
        .fonts(.display)
        .foregroundStyle(Asset.Colors.onGold.color)
      Text(L10n.ticketDescription)
        .fonts(.bodyMedium)
        .foregroundStyle(Asset.Colors.onGold.color.opacity(0.85))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(MutterGradient.gold, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }

  // MARK: - 내역

  private var historySection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.ticketHistory).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.inkSoft.color)
      if model.history.isEmpty {
        Text(L10n.ticketHistoryEmpty)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.inkFaint.color)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(model.history.enumerated()), id: \.offset) { _, item in
            TicketHistoryRowView(item: item)
          }
        }
        .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
      }
    }
  }
}
