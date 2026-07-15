import SwiftUI

import Domain
import UIComponent

/// 초대 수락 화면.
struct ConnectInviteView: View {
  @State private var model: ConnectInviteModelData
  private let onBack: () -> Void

  init(
    token: String,
    connectionUsecase: ConnectionUsecasable,
    onAccepted: @escaping () -> Void,
    onBack: @escaping () -> Void
  ) {
    self.onBack = onBack
    _model = State(initialValue: ConnectInviteModelData(
      token: token, connectionUsecase: connectionUsecase, onAccepted: onAccepted
    ))
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      // Mercury 패턴: navbar를 body 최상단 Component로 직접 배치(모디파이어 아님).
      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          L10n.inviteTitle,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )
        Spacer()
        
        content
          .padding(24)
          .frame(maxWidth: 420)
        
        Spacer()
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task { await model.load() }
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .loading:
      ProgressView().tint(Asset.Colors.gold.color)
    case .ready(let invite):
      ready(invite)
    case .accepted:
      message(icon: Asset.Images.checkCircle, title: L10n.inviteConnectedTitle, detail: L10n.inviteConnectedDetail)
    case .failed(let text):
      failed(text)
    }
  }

  private func ready(_ invite: ConnectInvite) -> some View {
    VStack(spacing: 16) {
      MutterIcon(Asset.Images.connect, size: 40).foregroundStyle(Asset.Colors.gold.color)
      Text(L10n.inviteRequest(invite.inviterNickname ?? L10n.inviteSomeone))
        .fonts(.title).foregroundStyle(Asset.Colors.ink.color).multilineTextAlignment(.center)

      if invite.canAccept {
        MutterButton(L10n.inviteConnect) { Task { await model.accept() } }
      } else {
        Text(reason(invite))
          .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color).multilineTextAlignment(.center)
      }
    }
  }

  private func reason(_ invite: ConnectInvite) -> String {
    if invite.isSelf { return L10n.inviteSelf }
    if invite.alreadyConnected { return L10n.inviteAlreadyConnected }
    if invite.viewerHasConnection { return L10n.inviteViewerHasConnection }
    if invite.inviterHasConnection { return L10n.inviteInviterHasConnection }
    return L10n.inviteUnavailable
  }

  /// 로드/수락 실패 상태 — 오류 메시지와 재시도 버튼 (EC-2.4).
  private func failed(_ text: String) -> some View {
    VStack(spacing: 16) {
      message(icon: Asset.Images.warning, title: L10n.inviteFailedTitle, detail: text)
      MutterButton(L10n.commonRetry, style: .ghost) { Task { await model.load() } }
    }
  }

  private func message(icon: ImageAsset, title: String, detail: String) -> some View {
    VStack(spacing: 12) {
      MutterIcon(icon, size: 40).foregroundStyle(Asset.Colors.gold.color)
      Text(title).fonts(.title).foregroundStyle(Asset.Colors.ink.color)
      Text(detail).fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color).multilineTextAlignment(.center)
    }
  }
}
