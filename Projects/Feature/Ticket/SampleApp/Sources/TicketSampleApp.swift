import SwiftUI

import Domain
import Router
import Ticket
import UIComponent

/// 결제 안내 시트를 서버·스토어 없이 띄워 보는 샘플 앱.
/// 실행 인자로 상황을 고른다: (없음) 보내기 전·편지권 없음 / `make` 이미 보낸 편지 / `keep` 받는 사람·편지권 없음 / `owned` 받는 사람·편지권 있음.
@main
struct TicketSampleApp: App {
  @State private var route: TicketCheckoutRoute?

  private var arguments: [String] { ProcessInfo.processInfo.arguments }

  var body: some Scene {
    WindowGroup {
      ZStack {
        Asset.Colors.ivory.color.ignoresSafeArea()
        MutterButton("결제 안내 열기") { route = initialRoute }
          .padding(40)
      }
      .onAppear { route = initialRoute }
      .sheet(item: $route) { route in
        TicketCheckoutView(
          route: route,
          ticketUsecase: SampleTicketUsecase(tickets: arguments.contains("owned") ? 2 : 0),
          purchaser: SampleTicketPurchaser(),
          onFinish: { _ in self.route = nil }
        )
      }
    }
  }

  private var initialRoute: TicketCheckoutRoute {
    arguments.contains("keep") || arguments.contains("owned")
      ? .keepReceived(token: "sample", password: nil)
      : (arguments.contains("make") ? .makePermanent(letterId: "sample") : .sendPermanent)
  }
}
