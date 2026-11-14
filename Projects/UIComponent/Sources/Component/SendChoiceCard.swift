import SwiftUI

/// 보내기 전 선택 카드 — "어떻게 보낼까요?" 아래 영구 편지(강조·먼저) / {n}일 편지 두 선택지.
/// 계약 "보내기 전 선택(보낸 사람)". 링크 발급 화면과 보내기 시트가 함께 쓴다(UIComponent는 Domain을 모르므로 값만 받는다).
public struct SendChoiceCard: View {
  private let ticketCount: Int
  private let freeDays: Int
  private let isLoading: Bool
  private let onPermanent: () -> Void
  private let onFreeDays: () -> Void

  public init(
    ticketCount: Int,
    freeDays: Int,
    isLoading: Bool = false,
    onPermanent: @escaping () -> Void,
    onFreeDays: @escaping () -> Void
  ) {
    self.ticketCount = ticketCount
    self.freeDays = freeDays
    self.isLoading = isLoading
    self.onPermanent = onPermanent
    self.onFreeDays = onFreeDays
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L10n.accessSendChoiceTitle)
        .fonts(.title)
        .foregroundStyle(Asset.Colors.ink.color)

      option(
        title: L10n.accessSendPermanent,
        detail: L10n.accessSendPermanentDetail,
        footnote: L10n.accessSendTicketBalance(ticketCount),
        price: L10n.accessSendPermanentPrice,
        isEmphasized: true,
        action: onPermanent
      )

      option(
        title: L10n.accessSendFreeDays(freeDays),
        detail: L10n.accessSendFreeDaysDetail(freeDays),
        footnote: nil,
        price: L10n.accessSendFree,
        isEmphasized: false,
        action: onFreeDays
      )
    }
  }

  private func option(
    title: String,
    detail: String,
    footnote: String?,
    price: String,
    isEmphasized: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .fonts(.bodyLargeBold)
            .foregroundStyle(Asset.Colors.ink.color)
          Text(detail)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkSoft.color)
          if let footnote {
            Text(footnote)
              .fonts(.captionBold)
              .foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .multilineTextAlignment(.leading)
        Spacer(minLength: 8)
        if isEmphasized && isLoading {
          ProgressView().tint(Asset.Colors.gold.color)
        } else {
          Text(price)
            .fonts(.bodyMediumBold)
            .foregroundStyle(isEmphasized ? Asset.Colors.goldDeep.color : Asset.Colors.inkMid.color)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isEmphasized ? Asset.Colors.goldSoft.color : Asset.Colors.surface.color,
        in: RoundedRectangle(cornerRadius: MutterRadius.lg)
      )
      .overlay(
        RoundedRectangle(cornerRadius: MutterRadius.lg)
          .strokeBorder(
            isEmphasized ? Asset.Colors.gold.color : Asset.Colors.hairline.color,
            lineWidth: isEmphasized ? 1.5 : 1
          )
      )
    }
    .buttonStyle(PressableButtonStyle())
    .disabled(isLoading)
  }
}
