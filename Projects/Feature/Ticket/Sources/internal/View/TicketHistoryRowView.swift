import SwiftUI

import Domain
import UIComponent

/// 편지권 내역 한 줄 — 사유(편지 제목) · 날짜 · 증감.
struct TicketHistoryRowView: View {
  let item: TicketHistoryItem

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(reasonText)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        Text(Self.dateFormatter.string(from: item.createdAt))
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      }
      Spacer()
      Text(item.delta.formatted(.number.sign(strategy: .always())))
        .fonts(.bodyMediumBold)
        .foregroundStyle(item.delta > 0 ? Asset.Colors.goldDeep.color : Asset.Colors.inkSoft.color)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  /// 사유 라벨 + 연결된 편지 제목(있으면).
  private var reasonText: String {
    guard let title = item.letterTitle, !title.isEmpty else { return reasonLabel }
    return "\(reasonLabel) · \(title)"
  }

  private var reasonLabel: String {
    switch item.reason {
    case .purchase: return L10n.ticketReasonPurchase
    case .use: return L10n.ticketReasonUse
    case .grant: return L10n.ticketReasonGrant
    case .refund: return L10n.ticketReasonRefund
    case .unknown: return L10n.ticketTitle
    }
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()
}
