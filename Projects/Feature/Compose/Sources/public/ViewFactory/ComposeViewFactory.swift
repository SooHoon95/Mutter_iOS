import SwiftUI

import Domain
import Router
import UIComponent

/// 제작 화면 팩토리. ComposeRoute(.new/.edit/.reply)→ComposeView.
public struct ComposeViewFactory: ViewFactory {
  private let letterUsecase: LetterUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let deliveryUsecase: DeliveryUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable
  private let audioUsecase: AudioUsecasable
  private let linkBaseURL: String
  private let onDone: () -> Void
  private let onBack: () -> Void
  private let ticketCheckout: TicketCheckoutBuilder

  public init(
    letterUsecase: LetterUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void,
    onBack: @escaping () -> Void,
    ticketCheckout: @escaping TicketCheckoutBuilder
  ) {
    self.letterUsecase = letterUsecase
    self.connectionUsecase = connectionUsecase
    self.deliveryUsecase = deliveryUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
    self.audioUsecase = audioUsecase
    self.linkBaseURL = linkBaseURL
    self.onDone = onDone
    self.onBack = onBack
    self.ticketCheckout = ticketCheckout
  }

  public func makeView(_ route: ComposeRoute) -> some View {
    switch route {
    case .new:
      composeView(mode: .new, title: L10n.composeNavNew)
    case .edit(let id):
      composeView(mode: .edit(id), title: L10n.composeNavEdit)
    case .reply(let recipientId):
      composeView(mode: .reply(recipientId), title: L10n.composeNavReply)
    }
  }

  private func composeView(mode: ComposeModelData.Mode, title: String) -> ComposeView {
    ComposeView(
      mode: mode,
      navTitle: title,
      letterUsecase: letterUsecase,
      connectionUsecase: connectionUsecase,
      deliveryUsecase: deliveryUsecase,
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase,
      audioUsecase: audioUsecase,
      linkBaseURL: linkBaseURL,
      onDone: onDone,
      onBack: onBack,
      ticketCheckout: ticketCheckout
    )
  }
}
