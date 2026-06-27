import Foundation
import Network
import Combine

/// 네트워크 연결 상태를 관찰한다. `NWPathMonitor`를 Combine으로 노출.
public final class NetworkMonitor: ObservableObject {
  public static let shared = NetworkMonitor()

  @Published public private(set) var isConnected: Bool = true

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.efreedom.mutter.networkmonitor")

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      // pathUpdateHandler는 백그라운드 큐에서 호출 → @Published는 메인에서 갱신해야 한다.
      let connected = (path.status == .satisfied)
      Task { @MainActor in self?.isConnected = connected }
    }
    monitor.start(queue: queue)
  }
}
