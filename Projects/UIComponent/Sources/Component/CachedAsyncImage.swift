import SwiftUI

/// 캐싱되는 비동기 이미지(Mercury `CachedAsyncImage` API 패턴).
/// `ImageCache`(환경 주입)에서 로드하고, 로딩/실패 시 placeholder를 보여준다.
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
  private let url: URL?
  private let content: (Image) -> Content
  private let placeholder: () -> Placeholder

  @Environment(\.imageCache) private var cache
  @State private var uiImage: UIImage?

  public init(
    url: URL?,
    @ViewBuilder content: @escaping (Image) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    self.url = url
    self.content = content
    self.placeholder = placeholder
  }

  public var body: some View {
    Group {
      if let uiImage {
        content(Image(uiImage: uiImage))
          .transition(.opacity)
      } else {
        placeholder()
      }
    }
    .task(id: url) {
      await load()
    }
  }

  private func load() async {
    guard let url else {
      uiImage = nil
      return
    }
    // url이 바뀌면 .task(id:)가 재실행된다. 이전 이미지를 그대로 두면 stale이 되므로
    // 캐시에서 새로 로드한다(메모리 히트면 즉시). 취소 시 상태를 갱신하지 않는다.
    let loaded = await cache.image(for: url)
    guard !Task.isCancelled, let loaded else { return }
    withAnimation(.easeOut(duration: 0.2)) {
      uiImage = loaded
    }
  }
}
