import SwiftUI

import Domain
import Router

/// Viewer 화면 팩토리. ViewerRoute→ViewerView. 수신/내편지 양쪽을 같은 화면으로 처리.
public struct ViewerViewFactory: ViewFactory {
  private let deliveryUsecase: DeliveryUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterUsecase: LetterUsecasable
  private let audioUsecase: AudioUsecasable

  public init(
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    audioUsecase: AudioUsecasable
  ) {
    self.deliveryUsecase = deliveryUsecase
    self.receiptUsecase = receiptUsecase
    self.letterUsecase = letterUsecase
    self.audioUsecase = audioUsecase
  }

  public func makeView(_ route: ViewerRoute) -> some View {
    switch route {
    case .token(let token, _):
      view(source: .token(token))
    case .myLetter(let letterId):
      view(source: .myLetter(letterId))
    }
  }

  private func view(source: ViewerModelData.Source) -> ViewerView {
    ViewerView(
      source: source,
      deliveryUsecase: deliveryUsecase,
      receiptUsecase: receiptUsecase,
      letterUsecase: letterUsecase,
      audioUsecase: audioUsecase
    )
  }
}
