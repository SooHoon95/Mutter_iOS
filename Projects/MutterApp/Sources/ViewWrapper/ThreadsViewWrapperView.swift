import SwiftUI

import AppFoundation
import Domain
import Infrastructure
import Router
import Threads

/// 주고받음(스레드) 탭 브리지. usecase는 `init`에서 생성자 주입으로 조립한다.
struct ThreadsViewWrapperView: View, ThreadsViewable {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  private let threadUsecase: ThreadUsecasable

  init() {
    self.threadUsecase = ThreadUsecase(repository: ThreadRepository())
  }

  var body: some View {
    ThreadsView(
      threadUsecase: threadUsecase,
      onReply: { coordinator.push(.compose(.reply(recipientId: $0))) },
      onOpen: { coordinator.push(.viewer(.token($0, password: nil))) }
    )
  }
}
