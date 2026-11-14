import SwiftUI

import Domain
import Router
import UIComponent

/// 결제 안내 시트 — 편지권이 필요한 동작을 눌렀는데 편지권이 없을 때 어디서나 같은 화면이 뜬다.
/// 보내는 사람(영구 편지로 보내기·만들기)과 받는 사람(간직하기)은 제목·설명·버튼 문구만 다르다.
/// 상품을 고르고 맨 아래 버튼을 누르면 구매 → 편지권 사용까지 이어서 하고 닫힌다.
/// 아직 안 보낸 편지는 구매까지만 한다(편지권은 링크를 만들거나 보낼 때 쓰인다).
public struct TicketCheckoutView: View {
  @State private var model: TicketCheckoutModelData
  /// 내용 높이 — 시트를 내용만큼만 올린다(편지권이 있을 때와 상품을 고를 때 높이가 다르다).
  @State private var contentHeight: CGFloat = 440
  private let onFinish: (Bool) -> Void

  /// - Parameter onFinish: 시트를 닫아 달라는 요청. `true`면 하려던 일(편지권 확보 또는 사용)을 마쳤다.
  public init(
    route: TicketCheckoutRoute,
    ticketUsecase: TicketUsecasable,
    purchaser: TicketPurchasing,
    onFinish: @escaping (Bool) -> Void
  ) {
    _model = State(initialValue: TicketCheckoutModelData(
      route: route,
      ticketUsecase: ticketUsecase,
      purchaser: purchaser
    ))
    self.onFinish = onFinish
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        points

        VStack(alignment: .leading, spacing: 10) {
          Text(L10n.accessSendTicketBalance(model.tickets))
            .fonts(.captionBold)
            .foregroundStyle(Asset.Colors.goldDeep.color)

          if !model.canUseNow {
            ForEach(model.products, id: \.self) { product in
              MutterChoiceRow(
                isSelected: model.selectedProduct == product,
                title: L10n.ticketProduct(product.ticketCount),
                trailing: model.prices[product],
                isEnabled: !model.isWorking
              ) {
                model.selectedProduct = product
              }
            }
          }
        }

        if let message = model.errorMessage {
          Text(message)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.danger.color)
        }

        VStack(spacing: 8) {
          MutterButton(buttonTitle, isLoading: model.isWorking || model.isLoading, isEnabled: model.canConfirm) {
            Task { await model.confirm() }
          }
          MutterButton(L10n.commonCancel, style: .ghost, isEnabled: !model.isWorking) {
            onFinish(false)
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 28)
      .padding(.bottom, 8)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Asset.Colors.surface.color)
    // 글자 크기를 키워 내용이 화면보다 길어지면 시스템이 높이를 화면에 맞추고, 안쪽은 스크롤된다.
    .presentationDetents([.height(contentHeight)])
    .presentationDragIndicator(.visible)
    // 구매·사용 도중에 쓸어내려 닫으면 결과를 놓친다.
    .interactiveDismissDisabled(model.isWorking)
    .task { await model.appear() }
    .onChange(of: model.isDone) {
      if model.isDone { onFinish(true) }
    }
  }

  // MARK: - 문구(보내기 전 / 이미 보낸 편지 / 받는 사람)

  private var isReceiver: Bool {
    if case .keepReceived = model.route { return true }
    return false
  }

  private var title: String {
    switch model.route {
    case .sendPermanent: return L10n.accessSendPermanent
    case .makePermanent: return L10n.checkoutMakeTitle
    case .keepReceived: return L10n.checkoutKeepTitle
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .fonts(.title)
        .foregroundStyle(Asset.Colors.ink.color)
      Text(isReceiver ? L10n.checkoutKeepSubtitle : L10n.accessSendPermanentDetail)
        .fonts(.bodyMedium)
        .foregroundStyle(Asset.Colors.inkSoft.color)
    }
  }

  private var points: some View {
    VStack(alignment: .leading, spacing: 8) {
      point(isReceiver ? L10n.checkoutKeepPoint1 : L10n.checkoutSendPoint1)
      point(isReceiver ? L10n.checkoutKeepPoint2 : L10n.checkoutSendPoint2)
    }
  }

  private func point(_ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      MutterIcon(Asset.Images.check, size: 14)
        .foregroundStyle(Asset.Colors.gold.color)
      Text(text)
        .fonts(.bodyMedium)
        .foregroundStyle(Asset.Colors.inkMid.color)
    }
  }

  private var buttonTitle: String {
    switch model.route {
    case .sendPermanent: return model.canUseNow ? L10n.checkoutSendUse : L10n.checkoutSendBuy
    case .makePermanent: return model.canUseNow ? L10n.checkoutMakeUse : L10n.checkoutMakeBuy
    case .keepReceived: return model.canUseNow ? L10n.checkoutKeepUse : L10n.checkoutKeepBuy
    }
  }
}
