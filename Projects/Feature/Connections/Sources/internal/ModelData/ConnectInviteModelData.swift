import Foundation

import AppFoundation
import Domain
import UIComponent

/// 초대 수락 화면 상태/로직(/connect/:token).
@MainActor
@Observable
final class ConnectInviteModelData {
  enum ViewState {
    case loading
    case ready(ConnectInvite)
    case accepted
    case failed(String)
  }

  var state: ViewState = .loading

  private let token: String
  private let connectionUsecase: ConnectionUsecasable
  private let onAccepted: () -> Void

  init(token: String, connectionUsecase: ConnectionUsecasable, onAccepted: @escaping () -> Void) {
    self.token = token
    self.connectionUsecase = connectionUsecase
    self.onAccepted = onAccepted
  }

  func load() async {
    // 이미 이 링크로 연결을 완료한 적이 있으면 서버에 재확인하지 않는다.
    // (단일 사용 토큰이 소비된 뒤 재오픈 시 "만료"로 오인 표시되던 문제 — 멱등 처리.)
    if AcceptedInviteStore.contains(token) {
      state = .accepted
      return
    }
    do {
      let invite = try await connectionUsecase.invite(token: token)
      state = .ready(invite)
    } catch {
      state = .failed((error as? MutterError)?.userMessage ?? L10n.errorInviteLoad)
    }
  }

  func accept() async {
    do {
      try await connectionUsecase.accept(token: token)
      AcceptedInviteStore.markAccepted(token)
      state = .accepted
      onAccepted()
    } catch {
      state = .failed((error as? MutterError)?.userMessage ?? L10n.errorInviteAccept)
    }
  }
}
