import Foundation

/// 의존성 등록·해결을 담당하는 Service Locator.
/// 앱 컴포지션 루트(`MutterApp`)에서 register하고, Feature/Repository는 `@Inject`/`@LazyInject`로 resolve한다.
/// (Mercury `MercuryContainer` 복제)
public final class MutterContainer {
  public static let shared = MutterContainer()

  private var registry: [ObjectIdentifier: Any] = [:]
  private let lock = NSRecursiveLock()

  private init() {}

  /// 인스턴스를 타입에 등록한다. 같은 타입을 다시 등록하면 덮어쓴다.
  public func register<T>(_ type: T.Type, instance: T) {
    lock.lock(); defer { lock.unlock() }
    registry[ObjectIdentifier(type)] = instance
  }

  /// 등록된 인스턴스를 해결한다. 미등록은 컴포지션 루트 배선 누락이므로 개발 단계에서 즉시 드러나게 crash.
  public func resolve<T>(_ type: T.Type) -> T {
    lock.lock(); defer { lock.unlock() }
    guard let instance = registry[ObjectIdentifier(type)] as? T else {
      fatalError("MutterContainer: \(type) 미등록 — 컴포지션 루트에서 register 누락")
    }
    return instance
  }

  /// 테스트/리셋용.
  public func reset() {
    lock.lock(); defer { lock.unlock() }
    registry.removeAll()
  }
}
