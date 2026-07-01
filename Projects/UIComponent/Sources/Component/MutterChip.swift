import SwiftUI

/// 음악/감정 태그 칩(디자인 시스템 `Chip`). 선택 시 연한 골드 채움 + 골드 테두리.
/// 선택적 리딩 아이콘. 높이 36, pill.
public struct MutterChip: View {
  private let label: String
  private let icon: ImageAsset?
  private let selected: Bool
  private let action: () -> Void

  public init(_ label: String, icon: ImageAsset? = nil, selected: Bool = false, action: @escaping () -> Void) {
    self.label = label
    self.icon = icon
    self.selected = selected
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon { MutterIcon(icon, size: 16) }
        Text(label).fonts(.bodyMedium)
      }
      .foregroundStyle(selected ? Asset.Colors.goldDeep.color : Asset.Colors.inkMid.color)
      .padding(.horizontal, 14)
      .frame(height: 36)
      .background(selected ? Asset.Colors.goldSoft.color : Asset.Colors.surface.color, in: Capsule())
      .overlay(Capsule().stroke(selected ? Asset.Colors.gold.color : Asset.Colors.hairlineStrong.color, lineWidth: 1))
    }
    .buttonStyle(PressableButtonStyle())
  }
}
