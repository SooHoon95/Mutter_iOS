import SwiftUI

import AppFoundation
import Domain
import Home
import Infrastructure
import Router

/// 홈 탭 브리지(Mercury ViewWrapper 패턴). usecase는 `init`에서 그 자리에 조립해 생성자 주입하고,
/// 네비게이션 콜백은 환경의 코디네이터로 배선한다(로케이터 미사용).
struct HomeViewWrapperView: View, HomeViewable {
  private let letterUsecase: LetterUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable

  init() {
    self.letterUsecase = LetterUsecase(repository: LetterRepository(), photoRepository: LetterPhotoRepository())
    self.receiptUsecase = ReceiptUsecase(repository: ReceiptRepository())
    self.letterAccessUsecase = LetterAccessUsecase(repository: LetterAccessRepository())
    self.ticketUsecase = TicketUsecase(repository: TicketRepository())
  }

  var body: some View {
    HomeView(
      letterUsecase: letterUsecase,
      receiptUsecase: receiptUsecase,
      letterAccessUsecase: letterAccessUsecase,
      ticketUsecase: ticketUsecase,
//      onCompose: { coordinator.push(.compose(.new)) },
//      onEdit: { coordinator.push(.compose(.edit(letterId: $0))) },
//      onPreview: { coordinator.push(.viewer(.myLetter(letterId: $0))) }
    )
  }
}
