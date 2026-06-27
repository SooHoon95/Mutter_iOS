import SwiftUI
import Combine

/// 화면 스택을 관리하는 네비게이션 코디네이터(Mercury 패턴 복제).
/// rootStack(메인 NavigationStack 경로) + 풀스크린 모달 스택을 분리 관리한다.
/// Feature는 Route만 알고, 이 코디네이터로 push/pop을 요청한다(Feature→Feature 의존 0).
@MainActor
public final class NavigationCoordinator<Route: Hashable>: ObservableObject {
  @Published public var rootStack: [Route] = []
  @Published public var isFullScreenPresented: Bool = false
  @Published public var fullScreenRoute: Route?
  @Published public var fullScreenStack: [Route] = []

  private let eventSubject = PassthroughSubject<NavigationEvent<Route>, Never>()
  private var cancellables = Set<AnyCancellable>()

  public init() {
    eventSubject
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        self?.handle(event: event)
      }
      .store(in: &cancellables)
  }

  // MARK: - Public Navigation API

  public func push(_ route: Route) { eventSubject.send(.push(route)) }
  public func pop() { eventSubject.send(.pop) }
  public func popToRoot() { eventSubject.send(.popToRoot) }
  public func popTo(_ route: Route) { eventSubject.send(.popTo(route)) }
  public func presentFullScreen(_ route: Route) { eventSubject.send(.presentFullScreen(route)) }
  public func dismissFullScreen() { eventSubject.send(.dismissFullScreen) }

  // MARK: - Internal

  private func handle(event: NavigationEvent<Route>) {
    switch event {
    case .push(let route):
      if isFullScreenPresented {
        fullScreenStack.append(route)
      } else {
        rootStack.append(route)
      }

    case .pop:
      if isFullScreenPresented {
        if !fullScreenStack.isEmpty {
          _ = fullScreenStack.popLast()
        } else {
          // 풀스크린 루트에서 pop이면 모달을 닫는다.
          isFullScreenPresented = false
          fullScreenRoute = nil
          fullScreenStack.removeAll()
        }
      } else {
        _ = rootStack.popLast()
      }

    case .popToRoot:
      if isFullScreenPresented {
        fullScreenStack.removeAll()
        isFullScreenPresented = false
        fullScreenRoute = nil
      }
      rootStack.removeAll()

    case .popTo(let route):
      if isFullScreenPresented {
        if let idx = fullScreenStack.lastIndex(of: route) {
          fullScreenStack = Array(fullScreenStack.prefix(idx + 1))
        }
      } else {
        if let idx = rootStack.lastIndex(of: route) {
          rootStack = Array(rootStack.prefix(idx + 1))
        }
      }

    case .presentFullScreen(let route):
      guard !isFullScreenPresented else { return }
      isFullScreenPresented = true
      fullScreenRoute = route
      fullScreenStack.removeAll()

    case .dismissFullScreen:
      guard isFullScreenPresented else { return }
      isFullScreenPresented = false
      fullScreenRoute = nil
      fullScreenStack.removeAll()
    }
  }
}
