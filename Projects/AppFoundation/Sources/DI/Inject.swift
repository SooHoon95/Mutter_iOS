import Foundation

/// 선언 즉시 `MutterContainer`에서 resolve하는 프로퍼티 래퍼.
@propertyWrapper
public struct Inject<T> {
  public let wrappedValue: T
  public init() { self.wrappedValue = MutterContainer.shared.resolve(T.self) }
}
