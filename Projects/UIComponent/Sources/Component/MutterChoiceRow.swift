import SwiftUI

/// 여러 개 중 하나를 고르는 줄(라디오) — 보내기 전 선택과 결제 안내의 상품 선택이 함께 쓴다.
/// 누르면 고르기만 한다. 실제 진행은 화면 맨 아래 버튼이 맡는다.
public struct MutterChoiceRow: View {
  private let isSelected: Bool
  private let title: String
  private let detail: String?
  private let footnote: String?
  private let trailing: String?
  private let isEnabled: Bool
  private let action: () -> Void

  public init(
    isSelected: Bool,
    title: String,
    detail: String? = nil,
    footnote: String? = nil,
    trailing: String? = nil,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.isSelected = isSelected
    self.title = title
    self.detail = detail
    self.footnote = footnote
    self.trailing = trailing
    self.isEnabled = isEnabled
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        radio
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .fonts(.bodyLargeBold)
            .foregroundStyle(Asset.Colors.ink.color)
          if let detail {
            Text(detail)
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.inkSoft.color)
          }
          if let footnote {
            Text(footnote)
              .fonts(.captionBold)
              .foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .multilineTextAlignment(.leading)
        Spacer(minLength: 8)
        if let trailing {
          Text(trailing)
            .fonts(.bodyMediumBold)
            .foregroundStyle(isSelected ? Asset.Colors.goldDeep.color : Asset.Colors.inkMid.color)
        }
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
    .disabled(!isEnabled)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var radio: some View {
    ZStack {
      Circle()
        .strokeBorder(isSelected ? Asset.Colors.gold.color : Asset.Colors.hairlineStrong.color, lineWidth: 1.5)
      if isSelected {
        Circle()
          .fill(Asset.Colors.gold.color)
          .padding(5)
      }
    }
    .frame(width: 22, height: 22)
  }
}
