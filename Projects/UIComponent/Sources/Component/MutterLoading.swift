import SwiftUI

/// 전역 로딩 인디케이터(Mercury `MercuryLoading` 패턴).
/// Mercury는 Lottie를 쓰지만, 의존을 줄이기 위해 SwiftUI 네이티브로 구현한다.
/// (Lottie 도입 시 `MutterLoadingView` 내부만 교체하면 호출부 불변.)
@Observable
public final class MutterLoading {
  public static let shared = MutterLoading()
  public var isLoading = false

  private init() {}

  public func show() { isLoading = true }
  public func hide() { isLoading = false }
}

/// 화면 위에 오버레이로 띄우는 로딩 뷰. 앱 루트에 한 번 배치한다.
public struct MutterLoadingView: View {
  private var model = MutterLoading.shared

  public init() {}

  public var body: some View {
    if model.isLoading {
      ZStack {
        Asset.Colors.ink.color.opacity(0.12).ignoresSafeArea()
        ProgressView()
          .controlSize(.large)
          .tint(Asset.Colors.gold.color)
          .padding(24)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
          .shadows(.card)
      }
      .transition(.opacity)
    }
  }
}

private struct MutterLoadingModifier: ViewModifier {
  let isLoading: Bool
  private var model = MutterLoading.shared

  init(isLoading: Bool) { self.isLoading = isLoading }

  func body(content: Content) -> some View {
    content
      .onChange(of: isLoading) { _, newValue in
        withAnimation(.easeInOut(duration: 0.2)) {
          newValue ? model.show() : model.hide()
        }
      }
      .onDisappear { model.hide() }
  }
}

public extension View {
  /// 이 뷰의 로딩 상태를 전역 로딩 오버레이에 연동한다.
  func loading(_ isLoading: Bool) -> some View {
    modifier(MutterLoadingModifier(isLoading: isLoading))
  }
}
