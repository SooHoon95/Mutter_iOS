import SwiftUI

import Domain
import Router

/// Viewer 화면 팩토리. ViewerRoute→ViewerView. 수신/내편지 양쪽을 같은 화면으로 처리.
public struct ViewerViewFactory: ViewFactory {
  private let deliveryUsecase: DeliveryUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterUsecase: LetterUsecasable
  /// nil이면 미인증 뷰어(능력 부재 = nil, Mercury DI 패턴).
  private let inboxUsecase: InboxUsecasable?
  private let audioUsecase: AudioUsecasable
  /// 뷰어 내부 내비바의 뒤로가기 콜백(coordinator.pop). 라우팅 레이어에서 주입.
  private let onBack: () -> Void

  public init(
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    inboxUsecase: InboxUsecasable?,
    audioUsecase: AudioUsecasable,
    onBack: @escaping () -> Void
  ) {
    self.deliveryUsecase = deliveryUsecase
    self.receiptUsecase = receiptUsecase
    self.letterUsecase = letterUsecase
    self.inboxUsecase = inboxUsecase
    self.audioUsecase = audioUsecase
    self.onBack = onBack
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
      inboxUsecase: inboxUsecase,
      audioUsecase: audioUsecase,
      onBack: onBack
    )
  }
}
