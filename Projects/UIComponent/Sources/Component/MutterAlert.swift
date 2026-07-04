import SwiftUI

/// 확인형 알럿 정보(버튼 1개).
public struct AlertConfirm {
  let title: String
  let message: String
  let confirmTitle: String
  let onConfirm: () -> Void

  public init(title: String, message: String, confirmTitle: String = "확인", onConfirm: @escaping () -> Void = {}) {
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.onConfirm = onConfirm
  }
}

/// 취소형 알럿 정보(취소 + 확인 2개).
public struct AlertCancellable {
  let title: String
  let message: String
  let confirmTitle: String
  let cancelTitle: String
  let isDestructive: Bool
  let onConfirm: () -> Void
  let onCancel: () -> Void

  public init(
    title: String,
    message: String,
    confirmTitle: String = "확인",
    cancelTitle: String = "취소",
    isDestructive: Bool = false,
    onConfirm: @escaping () -> Void = {},
    onCancel: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.cancelTitle = cancelTitle
    self.isDestructive = isDestructive
    self.onConfirm = onConfirm
    self.onCancel = onCancel
  }
}

public enum AlertInformType {
  case confirm(AlertConfirm)
  case cancellable(AlertCancellable)
}

/// 전역 알럿 매니저(Mercury `MercuryAlert` 패턴).
@Observable
public final class MutterAlert {
  public static let shared = MutterAlert()
  public var type: AlertInformType?

  private init() {}

  public func present(_ type: AlertInformType) {
    self.type = type
  }
}

/// 알럿 오버레이. 앱 루트에 한 번 배치한다.
public struct MutterAlertView: View {
  private var model = MutterAlert.shared
  @State private var animate = false

  public init() {}

  public var body: some View {
    if let type = model.type {
      ZStack {
        Asset.Colors.ink.color.opacity(0.4).ignoresSafeArea()
          .onTapGesture {}

        VStack(spacing: 20) {
          content(for: type)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
        .shadows(.shadowLow)
        .padding(.horizontal, 24)
        .scaleEffect(animate ? 1 : 0.85)
        .opacity(animate ? 1 : 0)
      }
      .onAppear {
        withAnimation(.easeInOut(duration: 0.12)) { animate = true }
      }
    }
  }

  @ViewBuilder
  private func content(for type: AlertInformType) -> some View {
    switch type {
    case .confirm(let info):
      header(title: info.title, message: info.message)
      MutterButton(info.confirmTitle) {
        dismiss { info.onConfirm() }
      }
    case .cancellable(let info):
      header(title: info.title, message: info.message)
      HStack(spacing: 8) {
        MutterButton(info.cancelTitle, style: .secondary) {
          dismiss { info.onCancel() }
        }
        MutterButton(info.confirmTitle) {
          dismiss { info.onConfirm() }
        }
      }
    }
  }

  private func header(title: String, message: String) -> some View {
    VStack(spacing: 8) {
      Text(title)
        .fonts(.title)
        .foregroundStyle(Asset.Colors.ink.color)
        .multilineTextAlignment(.center)
      if !message.isEmpty {
        Text(message)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.inkSoft.color)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func dismiss(_ action: @escaping () -> Void) {
    withAnimation(.easeInOut(duration: 0.12)) { animate = false }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      model.type = nil
      action()
    }
  }
}
