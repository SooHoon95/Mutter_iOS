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
      state = .accepted
      onAccepted()
    } catch {
      state = .failed((error as? MutterError)?.userMessage ?? L10n.errorInviteAccept)
    }
  }
}
