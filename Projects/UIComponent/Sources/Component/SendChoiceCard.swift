import SwiftUI

/// 보내기 전 선택 카드 — "어떻게 보낼까요?" 아래에서 영구 편지 / {n}일 편지 중 하나를 고르고, 맨 아래 버튼으로 진행한다.
/// 계약 "보내기 전 선택(보낸 사람)". 링크 발급 화면과 보내기 시트가 함께 쓴다(UIComponent는 Domain을 모르므로 값만 받는다).
///
/// 고르는 것과 진행하는 것을 나눈 이유: 선택지를 누르자마자 편지권이 쓰이거나 확인 팝업이 뜨지 않게 하고,
/// 버튼 문구로 무슨 일이 일어나는지(편지권 사용·구매·무료)를 미리 알린다.
public struct SendChoiceCard: View {
  private enum Choice {
    case permanent
    case freeDays
  }

  private let ticketCount: Int
  private let freeDays: Int
  private let hasTicket: Bool
  private let isLoading: Bool
  private let onPermanent: () -> Void
  private let onFreeDays: () -> Void

  @State private var choice: Choice = .permanent

  /// - Parameters:
  ///   - hasTicket: 영구 편지에 쓸 편지권이 있는지(관리자는 차감이 없어 true). false면 버튼이 구매로 이어진다.
  ///   - onPermanent: 영구 편지를 고르고 버튼을 눌렀다 — 편지권이 있으면 사용, 없으면 구매 화면.
  ///   - onFreeDays: {n}일 편지를 고르고 버튼을 눌렀다.
  public init(
    ticketCount: Int,
    freeDays: Int,
    hasTicket: Bool,
    isLoading: Bool = false,
    onPermanent: @escaping () -> Void,
    onFreeDays: @escaping () -> Void
  ) {
    self.ticketCount = ticketCount
    self.freeDays = freeDays
    self.hasTicket = hasTicket
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
        .permanent,
        title: L10n.accessChoicePermanent,
        detail: L10n.accessSendPermanentDetail,
        footnote: L10n.accessSendTicketBalance(ticketCount),
        price: L10n.accessSendPermanentPrice
      )

      option(
        .freeDays,
        title: L10n.accessChoiceFreeDays(freeDays),
        detail: L10n.accessSendFreeDaysDetail(freeDays),
        footnote: nil,
        price: L10n.accessSendFree
      )

      if choice == .permanent {
        Text(hasTicket ? L10n.accessSendPermanentConfirm : L10n.accessSendNeedsTicket)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
          .padding(.horizontal, 4)
      }

      MutterButton(buttonTitle, isLoading: isLoading) {
        switch choice {
        case .permanent: onPermanent()
        case .freeDays: onFreeDays()
        }
      }
      .padding(.top, 4)
    }
  }

  private var buttonTitle: String {
    switch choice {
    case .permanent: return hasTicket ? L10n.accessSendPermanent : L10n.accessSendBuyTicket
    case .freeDays: return L10n.accessSendFreeDays(freeDays)
    }
  }

  private func option(
    _ value: Choice,
    title: String,
    detail: String,
    footnote: String?,
    price: String
  ) -> some View {
    let isSelected = choice == value
    return Button {
      withAnimation(.easeInOut(duration: 0.15)) { choice = value }
    } label: {
      HStack(alignment: .center, spacing: 12) {
        radio(isOn: isSelected)
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
        Text(price)
          .fonts(.bodyMediumBold)
          .foregroundStyle(isSelected ? Asset.Colors.goldDeep.color : Asset.Colors.inkMid.color)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isSelected ? Asset.Colors.goldSoft.color : Asset.Colors.surface.color,
        in: RoundedRectangle(cornerRadius: MutterRadius.lg)
      )
      .overlay(
        RoundedRectangle(cornerRadius: MutterRadius.lg)
          .strokeBorder(
            isSelected ? Asset.Colors.gold.color : Asset.Colors.hairline.color,
            lineWidth: isSelected ? 1.5 : 1
          )
      )
    }
    .buttonStyle(PressableButtonStyle())
    .disabled(isLoading)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func radio(isOn: Bool) -> some View {
    ZStack {
      Circle()
        .strokeBorder(isOn ? Asset.Colors.gold.color : Asset.Colors.hairlineStrong.color, lineWidth: 1.5)
      if isOn {
        Circle()
          .fill(Asset.Colors.gold.color)
          .padding(5)
      }
    }
    .frame(width: 22, height: 22)
  }
}
