import SwiftUI

import Domain
import Infrastructure
import Router
import UIComponent

/// 메인 탭 위에 새 소식 안내를 한 번 띄운다. 사양 `docs/specs/2026-11-15-whats-new.md` "언제 뜨나".
/// 대상(`WhatsNewStore.isPending`)이고 편지권 기능이 켜진 계정(`paid_enabled`, 관리자 제외)일 때만 —
/// 유료 전환 전에 업데이트한 사람은 전환된 뒤 처음 앱을 열 때 본다.
struct WhatsNewGate: ViewModifier {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  /// 띄울 때 문구에 넣을 일수를 가진 권한. nil이면 닫혀 있다.
  @State private var entitlements: Entitlements?
  private let ticketUsecase: TicketUsecasable

  init() {
    self.ticketUsecase = TicketUsecase(repository: TicketRepository())
  }

  func body(content: Content) -> some View {
    content
      .task { await presentIfNeeded() }
      .fullScreenCover(isPresented: Binding(get: { entitlements != nil }, set: { if !$0 { entitlements = nil } })) {
        if let entitlements {
          WhatsNewView(freeDays: entitlements.freeDays, graceDays: entitlements.graceDays) {
            self.entitlements = nil
          }
        }
      }
  }

  private func presentIfNeeded() async {
    guard WhatsNewStore.isPending else { return }
    // 권한을 받지 못했거나 아직 편지권이 켜지지 않았으면 그대로 둔다 — 다음에 앱을 열 때 다시 확인한다.
    guard let loaded = try? await ticketUsecase.entitlements(), loaded.paidEnabled, !loaded.isAdmin else { return }
    // 알림·링크로 편지나 다른 화면이 이미 올라와 있으면 그 위를 덮지 않는다(다음 실행 때 보인다).
    guard coordinator.rootStack.isEmpty, !coordinator.isFullScreenPresented else { return }
    WhatsNewStore.markSeen()
    entitlements = loaded
  }
}
