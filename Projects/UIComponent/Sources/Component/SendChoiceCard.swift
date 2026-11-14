import SwiftUI

/// 보내기 전 선택 카드 — "어떻게 보낼까요?" 아래에서 영구 편지 / {n}일 편지 중 하나를 고르고, 맨 아래 버튼으로 진행한다.
/// 계약 "보내기 전 선택(보낸 사람)". 링크 발급 화면과 보내기 시트가 함께 쓴다(UIComponent는 Domain을 모르므로 값만 받는다).
///
/// 고르는 것과 진행하는 것을 나눈 이유: 선택지를 누르자마자 편지권이 쓰이거나 확인 팝업이 뜨지 않게 한다.
/// 편지권이 있으면 버튼 위에 "편지권 1장을 사용해요"를 미리 알리고, 없으면 버튼이 결제 안내 시트로 이어진다.
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
  ///   - hasTicket: 영구 편지에 쓸 편지권이 있는지(관리자는 차감이 없어 true).
  ///   - onPermanent: 영구 편지를 고르고 버튼을 눌렀다 — 편지권이 있으면 사용, 없으면 결제 안내.
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

      MutterChoiceRow(
        isSelected: choice == .permanent,
        title: L10n.accessChoicePermanent,
        detail: L10n.accessSendPermanentDetail,
        footnote: L10n.accessSendTicketBalance(ticketCount),
        trailing: L10n.accessSendPermanentPrice,
        isEnabled: !isLoading
      ) {
        withAnimation(.easeInOut(duration: 0.15)) { choice = .permanent }
      }

      MutterChoiceRow(
        isSelected: choice == .freeDays,
        title: L10n.accessChoiceFreeDays(freeDays),
        detail: L10n.accessSendFreeDaysDetail(freeDays),
        trailing: L10n.accessSendFree,
        isEnabled: !isLoading
      ) {
        withAnimation(.easeInOut(duration: 0.15)) { choice = .freeDays }
      }

      if choice == .permanent && hasTicket {
        Text(L10n.accessSendPermanentConfirm)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
          .padding(.horizontal, 4)
      }

      MutterButton(
        choice == .permanent ? L10n.accessSendPermanent : L10n.accessSendFreeDays(freeDays),
        isLoading: isLoading
      ) {
        switch choice {
        case .permanent: onPermanent()
        case .freeDays: onFreeDays()
        }
      }
      .padding(.top, 4)
    }
  }
}
