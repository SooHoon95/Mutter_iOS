import SwiftUI

public extension View {
  /// 조건부 모디파이어 적용. `view.applyIf(isActive) { $0.opacity(0.5) }`
  @ViewBuilder
  func applyIf<Content: View>(
    _ condition: Bool,
    transform: (Self) -> Content
  ) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }

  /// 이미지 캐시를 환경에 주입한다(`CachedAsyncImage`가 참조).
  func imageCache(_ cache: ImageCache) -> some View {
    environment(\.imageCache, cache)
  }
}
