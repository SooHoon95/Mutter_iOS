import SwiftUI

import AppFoundation
import Connections
import Domain
import Infrastructure
import Router

/// 연결 탭 브리지. usecase는 `init`에서 생성자 주입으로 조립한다.
struct ConnectionsViewWrapperView: View, ConnectionsViewable {
  private let connectionUsecase: ConnectionUsecasable

  init() {
    self.connectionUsecase = ConnectionUsecase(repository: ConnectionRepository())
  }

  var body: some View {
    ConnectionsView(connectionUsecase: connectionUsecase, inviteBaseURL: AppLink.baseURL)
  }
}
