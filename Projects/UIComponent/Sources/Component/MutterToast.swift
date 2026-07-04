import SwiftUI

/// 토스트 종류 — 아이콘/톤 결정.
public enum ToastType {
  case common
  case success
  case error

  var icon: ImageAsset {
    switch self {
    case .common: Asset.Images.check
    case .success: Asset.Images.checkCircle
    case .error: Asset.Images.warning
    }
  }

  var iconColor: Color {
    switch self {
    case .common: Asset.Colors.goldSoft.color
    case .success: Asset.Colors.gold.color
    case .error: Asset.Colors.goldLight.color
    }
  }
}

/// 토스트 표시 시간.
public enum ToastTime: Double {
  case short = 1.0
  case medium = 2.0
  case long = 3.5
}

private struct ToastItem: Identifiable {
  let id = UUID()
  let title: String
  let type: ToastType
  let timing: ToastTime
}

/// 전역 토스트 매니저(Mercury `MercuryToast` 패턴, Lottie/Asset.Images 대신 SF Symbol).
@Observable
public final class MutterToast {
  public static let shared = MutterToast()
  fileprivate var toasts: [ToastItem] = []

  private init() {}

  public func present(_ title: String, type: ToastType = .common, timing: ToastTime = .medium) {
    withAnimation(.snappy) {
      toasts.append(ToastItem(title: title, type: type, timing: timing))
    }
  }

  fileprivate func remove(_ id: UUID) {
    toasts.removeAll { $0.id == id }
  }
}

/// 토스트 스택 컨테이너. 앱 루트에 한 번 배치한다.
public struct MutterToastGroup: View {
  private var model = MutterToast.shared

  public init() {}

  public var body: some View {
    VStack(spacing: 8) {
      ForEach(model.toasts) { item in
        ToastRow(item: item)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.bottom, 24)
    .padding(.horizontal, 20)
  }
}

private struct ToastRow: View {
  let item: ToastItem
  @State private var visible = false

  var body: some View {
    HStack(spacing: 10) {
      MutterIcon(item.type.icon, size: 18)
        .foregroundStyle(item.type.iconColor)
      Text(item.title)
        .fonts(.bodyMediumBold)
        .foregroundStyle(Asset.Colors.ivory.color)
        .lineLimit(2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Asset.Colors.ink.color, in: Capsule())
    .shadows(.shadowLow)
    .opacity(visible ? 1 : 0)
    .offset(y: visible ? 0 : 16)
    .task {
      withAnimation(.snappy) { visible = true }
      try? await Task.sleep(for: .seconds(item.timing.rawValue))
      withAnimation(.snappy) { visible = false }
      try? await Task.sleep(for: .milliseconds(220))
      MutterToast.shared.remove(item.id)
    }
  }
}
