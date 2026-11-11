import SwiftUI

/// 편지 접근 상태 배지(목록 행) — `영구` / `{n}일 남음` / 자물쇠 + `닫힘`.
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
      Text(text).fonts(.caption)
    }
    .foregroundStyle(isLocked ? Asset.Colors.inkFaint.color : Asset.Colors.goldDeep.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(isLocked ? Asset.Colors.warm100.color : Asset.Colors.goldSoft.color, in: Capsule())
  }
}
