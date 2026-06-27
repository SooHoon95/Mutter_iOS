import SwiftUI

import Domain
import Router

/// 제작 화면 팩토리. ComposeRoute(.new/.edit/.reply)→ComposeView.
public struct ComposeViewFactory: ViewFactory {
  private let letterUsecase: LetterUsecasable
  private let catalogUsecase: CatalogUsecasable
  private let connectionUsecase: ConnectionUsecasable
  private let audioUsecase: AudioUsecasable
  private let onDone: () -> Void

  public init(
    letterUsecase: LetterUsecasable,
    catalogUsecase: CatalogUsecasable,
    connectionUsecase: ConnectionUsecasable,
    audioUsecase: AudioUsecasable,
    onDone: @escaping () -> Void
  ) {
    self.letterUsecase = letterUsecase
    self.catalogUsecase = catalogUsecase
    self.connectionUsecase = connectionUsecase
    self.audioUsecase = audioUsecase
    self.onDone = onDone
  }

  public func makeView(_ route: ComposeRoute) -> some View {
    switch route {
    case .new:
      composeView(mode: .new)
    case .edit(let id):
      composeView(mode: .edit(id))
    case .reply(let recipientId):
      composeView(mode: .reply(recipientId))
    }
  }

  private func composeView(mode: ComposeModelData.Mode) -> ComposeView {
    ComposeView(
      mode: mode,
      letterUsecase: letterUsecase,
      catalogUsecase: catalogUsecase,
      connectionUsecase: connectionUsecase,
      audioUsecase: audioUsecase,
      onDone: onDone
    )
  }
}
