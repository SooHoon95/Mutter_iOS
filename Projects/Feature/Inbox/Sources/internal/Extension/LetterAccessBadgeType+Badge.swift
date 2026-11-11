import SwiftUI

import Domain
import UIComponent

extension LetterAccessBadgeType {
  /// 목록 배지 — 계약 문구 `영구` / `{n}일 남음` / `닫힘`.
  var badge: LetterAccessBadge {
    switch self {
    case .permanent: return LetterAccessBadge(L10n.accessPermanent)
    case .daysLeft(let days): return LetterAccessBadge(L10n.accessDaysLeft(days))
    case .locked: return LetterAccessBadge(L10n.accessLocked, isLocked: true)
    }
  }
}
