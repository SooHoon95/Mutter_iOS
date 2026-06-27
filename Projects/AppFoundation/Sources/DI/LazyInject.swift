import Foundation

/// 최초 접근 시 resolve하는 프로퍼티 래퍼. 순환 의존 가능 지점(ModelData·Repository)에서 사용한다.
@propertyWrapper
public final class LazyInject<T> {
  private var cached: T?
  public init() {}

  public var wrappedValue: T {
    if let cached { return cached }
    let resolved = MutterContainer.shared.resolve(T.self)
    cached = resolved
    return resolved
  }
}
