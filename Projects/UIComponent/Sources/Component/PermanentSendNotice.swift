import SwiftUI

/// 보내기 전 선택에서 영구 편지를 고른 뒤, 발급 폼·연결 상대 목록 위에 두는 안내.
/// 편지권은 아직 쓰이지 않았고 실제로 보낼 때 쓰인다는 것을 알리고, 마음을 바꿀 수 있게 "다시 고르기"를 준다.
public struct PermanentSendNotice: View {
  private let onChooseAgain: () -> Void

  public init(onChooseAgain: @escaping () -> Void) {
    self.onChooseAgain = onChooseAgain
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(L10n.accessSendPermanentChosen)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
        Text(L10n.accessSendPermanentHint)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      }
      .multilineTextAlignment(.leading)
      Spacer(minLength: 8)
      Button(action: onChooseAgain) {
        Text(L10n.accessChooseAgain)
          .fonts(.captionBold)
          .foregroundStyle(Asset.Colors.goldDeep.color)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Asset.Colors.goldSoft.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
  }
}
