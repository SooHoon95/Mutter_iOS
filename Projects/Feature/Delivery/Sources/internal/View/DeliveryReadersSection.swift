import SwiftUI

import Domain
import UIComponent

/// 보낸 편지의 열람자 목록 — `{닉네임} · {M}월 {D}일에 열어봄`(처음 연 날, 처음 연 순).
struct DeliveryReadersSection: View {
  let readers: [LetterReader]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.accessReaders).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.inkSoft.color)
      VStack(alignment: .leading, spacing: 0) {
        ForEach(readers) { reader in
          HStack(spacing: 10) {
            MutterIcon(Asset.Images.envelopeOpen, size: 18)
              .foregroundStyle(Asset.Colors.gold.color)
            Text(rowText(reader))
              .fonts(.bodyMedium)
              .foregroundStyle(Asset.Colors.inkMid.color)
              .lineLimit(1)
            Spacer()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
        }
      }
      .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
    }
  }

  private func rowText(_ reader: LetterReader) -> String {
    let name = reader.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.accessReaderUnnamed
    let parts = Calendar.current.dateComponents([.month, .day], from: reader.firstOpenedAt)
    return L10n.accessReader(name, parts.month ?? 0, parts.day ?? 0)
  }
}
