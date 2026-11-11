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
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable

  init() {
    self.inboxUsecase = InboxUsecase(repository: InboxRepository())
    self.letterAccessUsecase = LetterAccessUsecase(repository: LetterAccessRepository())
    self.ticketUsecase = TicketUsecase(repository: TicketRepository())
  }

  var body: some View {
    InboxView(
      inboxUsecase: inboxUsecase,
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase,
      onOpen: { coordinator.push(.viewer(.token($0, password: nil))) },
      onOpenTrash: { coordinator.push(.inboxTrash) }
    )
  }
}
