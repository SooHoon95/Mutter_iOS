import SwiftUI

import Domain
import UIComponent

extension LetterAccessBadgeType {
  /// 목록 배지 — 계약 문구 `영구` / `{n}일 남음` / 자물쇠 + `{n}일 뒤 삭제`(당일 `오늘 삭제`, 날짜를 모르면 `닫힘`).
  var badge: LetterAccessBadge {
    switch self {
    case .permanent: return LetterAccessBadge(L10n.accessPermanent)
    case .daysLeft(let days): return LetterAccessBadge(L10n.accessDaysLeft(days))
    case .locked(let deleteInDays):
      let text: String
      switch deleteInDays {
      case .none: text = L10n.accessLocked
      case .some(0): text = L10n.accessLockedDeleteToday
      case .some(let days): text = L10n.accessLockedDeleteIn(days)
      }
      return LetterAccessBadge(text, isLocked: true)
    }
  }
}
