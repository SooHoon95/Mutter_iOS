import SwiftUI

/// 편지 접근 상태 배지(목록 행) — `영구` / `{n}일 남음` / 자물쇠 + `{n}일 뒤 삭제`(날짜를 모르면 `닫힘`).
/// 닫힌 편지는 좁은 줄에서 접히지 않게 "닫힘" 글자를 자물쇠가 대신한다 — 읽어 주기 문구에는 "닫힘"을 넣는다.
/// 문구는 호출부가 Domain 상태에서 골라 넘긴다(UIComponent는 Domain을 모른다).
public struct LetterAccessBadge: View {
  private let text: String
  private let isLocked: Bool

  public init(_ text: String, isLocked: Bool = false) {
    self.text = text
    self.isLocked = isLocked
  }

  public var body: some View {
    HStack(spacing: 3) {
      if isLocked { MutterIcon(Asset.Images.lock, size: 11) }
      Text(text).fonts(.caption).lineLimit(1)
    }
    .fixedSize()
    .foregroundStyle(isLocked ? Asset.Colors.inkFaint.color : Asset.Colors.goldDeep.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(isLocked ? Asset.Colors.warm100.color : Asset.Colors.goldSoft.color, in: Capsule())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isLocked && text != L10n.accessLocked ? "\(L10n.accessLocked), \(text)" : text)
  }
}
