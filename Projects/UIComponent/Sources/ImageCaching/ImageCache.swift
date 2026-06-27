import SwiftUI

/// 경량 이미지 캐시. 인메모리(NSCache) + URLSession 다운로드.
/// 프로필 아바타·SoundCloud 썸네일 등 소수 이미지에 충분하다.
/// (디스크 캐시가 필요해지면 이 타입 내부만 교체하면 된다 — 호출부 불변.)
public final class ImageCache: @unchecked Sendable {
  public static let shared = ImageCache()

  private let memory = NSCache<NSURL, UIImage>()
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
    memory.countLimit = 120
  }

  /// 캐시에 있으면 즉시, 없으면 다운로드 후 캐시에 저장하고 반환한다.
  /// 실패 시 nil(호출부가 placeholder 유지).
  public func image(for url: URL) async -> UIImage? {
    let key = url as NSURL
    if let cached = memory.object(forKey: key) {
      return cached
    }
    do {
      let (data, _) = try await session.data(from: url)
      guard let image = UIImage(data: data) else { return nil }
      memory.setObject(image, forKey: key)
      return image
    } catch {
      return nil
    }
  }
}

// MARK: - Environment

private struct ImageCacheKey: EnvironmentKey {
  static let defaultValue = ImageCache.shared
}

public extension EnvironmentValues {
  var imageCache: ImageCache {
    get { self[ImageCacheKey.self] }
    set { self[ImageCacheKey.self] = newValue }
  }
}
