import SwiftUI

/// View 생애 첫 1회만 실행되는 onLoad. (`onAppear`는 재진입마다 호출되는 것과 구분)
private struct ViewDidLoadModifier: ViewModifier {
  @State private var didLoad = false
  let action: () -> Void

  func body(content: Content) -> some View {
    content.onAppear {
      guard !didLoad else { return }
      didLoad = true
      action()
    }
  }
}

public extension View {
  func onLoad(_ action: @escaping () -> Void) -> some View {
    modifier(ViewDidLoadModifier(action: action))
  }
}
