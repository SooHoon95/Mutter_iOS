import Foundation
import Network

/// 네트워크 연결 상태를 관찰한다. `NWPathMonitor`를 `@Observable`로 노출.
/// (`@Observable`과 `@Published`/`ObservableObject`는 함께 못 쓴다 — `_isConnected` 합성 충돌.
///  소비처는 `.environment(NetworkMonitor.shared)`로 주입하므로 `@Observable`만 사용한다.)
@Observable
public final class NetworkMonitor {
  public static let shared = NetworkMonitor()

  public private(set) var isConnected: Bool = true

  @ObservationIgnored private let monitor = NWPathMonitor()
  @ObservationIgnored private let queue = DispatchQueue(label: "com.efreedom.mutter.networkmonitor")

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      // pathUpdateHandler는 백그라운드 큐에서 호출 → 상태는 메인에서 갱신한다.
      let connected = (path.status == .satisfied)
      Task { @MainActor in self?.isConnected = connected }
    }
    monitor.start(queue: queue)
  }
}
