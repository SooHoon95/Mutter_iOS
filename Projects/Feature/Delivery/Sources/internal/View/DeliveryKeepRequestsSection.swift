import SwiftUI

import Domain
import UIComponent

/// 보낸 편지의 간직 요청자 — `{닉네임}님이 간직하고 싶어 해요`(요청한 순).
struct DeliveryKeepRequestsSection: View {
  let requests: [LetterKeepRequest]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(requests) { request in
        HStack(spacing: 10) {
          MutterIcon(Asset.Images.envelope, size: 18)
            .foregroundStyle(Asset.Colors.gold.color)
          Text(rowText(request))
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkMid.color)
            .lineLimit(2)
          Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
    }
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }

  private func rowText(_ request: LetterKeepRequest) -> String {
    guard let name = request.nickname, !name.isEmpty else { return L10n.accessKeepRequesterUnnamed }
    return L10n.accessKeepRequester(name)
  }
}
