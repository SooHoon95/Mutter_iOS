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
  private let letterAccessUsecase: LetterAccessUsecasable
  /// nil이면 미인증 — 잠긴 편지에 편지권을 쓸 수 없다.
  private let ticketUsecase: TicketUsecasable?
  private let audioUsecase: AudioUsecasable
  /// 뷰어 내부 내비바의 뒤로가기 콜백(coordinator.pop). 라우팅 레이어에서 주입.
  private let onBack: () -> Void
  /// 봉투 화면의 "편지 열기" — 로그인 후 같은 편지로 돌아오게 하는 건 라우팅 레이어 몫. nil이면 버튼을 숨긴다.
  private let onLoginRequest: (() -> Void)?
  /// 편지권이 없을 때 편지권 화면으로.
  private let onOpenTickets: () -> Void

  public init(
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    inboxUsecase: InboxUsecasable?,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable?,
    audioUsecase: AudioUsecasable,
    onBack: @escaping () -> Void,
    onLoginRequest: (() -> Void)? = nil,
    onOpenTickets: @escaping () -> Void = {}
  ) {
    self.deliveryUsecase = deliveryUsecase
    self.receiptUsecase = receiptUsecase
    self.letterUsecase = letterUsecase
    self.inboxUsecase = inboxUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
    self.audioUsecase = audioUsecase
    self.onBack = onBack
    self.onLoginRequest = onLoginRequest
    self.onOpenTickets = onOpenTickets
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
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase,
      audioUsecase: audioUsecase,
      onBack: onBack,
      onLoginRequest: onLoginRequest,
      onOpenTickets: onOpenTickets
    )
  }
}
