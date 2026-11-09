import SwiftUI

/// 하단 토스트 + 선택 액션 버튼(예: "되돌리기").
/// 표시 여부·노출 시간은 화면(ModelData)이 정한다 — 되돌리기 창이 닫히는 순간에 실제 요청을 보내야 하는
/// 지연 삭제처럼, 토스트 수명이 화면 상태와 묶여 있어야 하는 경우를 위해 상태 없는 뷰로 둔다.
/// 호출부는 `.overlay(alignment: .bottom)`에 조건부로 얹는다.
public struct MutterActionToast: View {
  private let message: String
  private let actionTitle: String?
  private let action: (() -> Void)?

  public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  public var body: some View {
    HStack(spacing: 12) {
      Text(message)
        .fonts(.bodyMediumBold)
        .foregroundStyle(Asset.Colors.ivory.color)
        .lineLimit(2)
      if let actionTitle, let action {
        Spacer(minLength: 0)
        Button(action: action) {
          Text(actionTitle)
            .fonts(.bodyMediumBold)
            .foregroundStyle(Asset.Colors.goldLight.color)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .background(Asset.Colors.ink.color, in: Capsule())
    .shadows(.shadowLow)
    .padding(.horizontal, 20)
    .padding(.bottom, 24)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }
}

#Preview {
  VStack(spacing: 12) {
    MutterActionToast("편지를 삭제함으로 옮겼어요", actionTitle: "되돌리기") {}
    MutterActionToast("편지를 되살렸어요")
  }
}
