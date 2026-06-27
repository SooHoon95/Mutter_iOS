import SwiftUI

import Domain
import Router

/// 연결 초대 수락 화면 팩토리(/connect/:token → ConnectRoute.invite).
public struct ConnectViewFactory: ViewFactory {
  private let connectionUsecase: ConnectionUsecasable
  private let onAccepted: () -> Void

  public init(connectionUsecase: ConnectionUsecasable, onAccepted: @escaping () -> Void) {
    self.connectionUsecase = connectionUsecase
    self.onAccepted = onAccepted
  }

  public func makeView(_ route: ConnectRoute) -> some View {
    switch route {
    case .invite(let token):
      ConnectInviteView(token: token, connectionUsecase: connectionUsecase, onAccepted: onAccepted)
    }
  }
}
