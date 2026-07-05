import SwiftUI

import Domain
import Router

/// 제작 화면 팩토리. ComposeRoute(.new/.edit/.reply)→ComposeView.
public struct ComposeViewFactory: ViewFactory {
  private let letterUsecase: LetterUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let deliveryUsecase: DeliveryUsecasable
  private let audioUsecase: AudioUsecasable
  private let linkBaseURL: String
  private let onDone: () -> Void
  private let onBack: () -> Void

  public init(
    letterUsecase: LetterUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void,
    onBack: @escaping () -> Void
  ) {
    self.letterUsecase = letterUsecase
    self.connectionUsecase = connectionUsecase
    self.deliveryUsecase = deliveryUsecase
    self.audioUsecase = audioUsecase
    self.linkBaseURL = linkBaseURL
    self.onDone = onDone
    self.onBack = onBack
  }

  public func makeView(_ route: ComposeRoute) -> some View {
    switch route {
    case .new:
      composeView(mode: .new, title: "편지 쓰기")
    case .edit(let id):
      composeView(mode: .edit(id), title: "이어쓰기")
    case .reply(let recipientId):
      composeView(mode: .reply(recipientId), title: "답장")
    }
  }

  private func composeView(mode: ComposeModelData.Mode, title: String) -> ComposeView {
    ComposeView(
      mode: mode,
      navTitle: title,
      letterUsecase: letterUsecase,
      connectionUsecase: connectionUsecase,
      deliveryUsecase: deliveryUsecase,
      audioUsecase: audioUsecase,
      linkBaseURL: linkBaseURL,
      onDone: onDone,
      onBack: onBack
    )
  }
}
