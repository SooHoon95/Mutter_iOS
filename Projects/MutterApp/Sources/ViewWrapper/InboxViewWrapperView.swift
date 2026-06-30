import SwiftUI

import AppFoundation
import Domain
import Inbox
import Infrastructure
import Router

/// 받은함 탭 브리지. usecase는 `init`에서 생성자 주입으로 조립한다.
struct InboxViewWrapperView: View, InboxViewable {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  private let inboxUsecase: InboxUsecasable

  init() {
    self.inboxUsecase = InboxUsecase(repository: InboxRepository())
  }

  var body: some View {
    InboxView(
      inboxUsecase: inboxUsecase,
      onOpen: { coordinator.push(.viewer(.token($0, password: nil))) }
    )
  }
}
