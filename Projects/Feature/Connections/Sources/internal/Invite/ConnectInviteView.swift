import SwiftUI

import Domain
import UIComponent

/// 초대 수락 화면.
struct ConnectInviteView: View {
  @State private var model: ConnectInviteModelData

  init(token: String, connectionUsecase: ConnectionUsecasable, onAccepted: @escaping () -> Void) {
    _model = State(initialValue: ConnectInviteModelData(
      token: token, connectionUsecase: connectionUsecase, onAccepted: onAccepted
    ))
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      content
        .padding(24)
        .frame(maxWidth: 420)
    }
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
      message(icon: "checkmark.circle.fill", title: "연결됐어요", detail: "이제 서로에게 편지를 보낼 수 있어요.")
    case .failed(let text):
      message(icon: "exclamationmark.triangle.fill", title: "연결할 수 없어요", detail: text)
    }
  }

  private func ready(_ invite: ConnectInvite) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "person.2.fill").font(.system(size: 32)).foregroundStyle(Asset.Colors.gold.color)
      Text("\(invite.inviterNickname ?? "누군가")님이\n연결을 요청했어요")
        .fonts(.title).foregroundStyle(Asset.Colors.ink.color).multilineTextAlignment(.center)

      if invite.canAccept {
        MutterButton("연결하기") { Task { await model.accept() } }
      } else {
        Text(reason(invite))
          .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color).multilineTextAlignment(.center)
      }
    }
  }

  private func reason(_ invite: ConnectInvite) -> String {
    if invite.isSelf { return "내가 만든 초대예요." }
    if invite.alreadyConnected { return "이미 연결된 사이예요." }
    if invite.viewerHasConnection { return "이미 다른 사람과 연결돼 있어요. 해제 후 다시 시도하세요." }
    if invite.inviterHasConnection { return "상대가 이미 다른 사람과 연결돼 있어요." }
    return "지금은 연결할 수 없어요."
  }

  private func message(icon: String, title: String, detail: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: icon).font(.system(size: 32)).foregroundStyle(Asset.Colors.gold.color)
      Text(title).fonts(.title).foregroundStyle(Asset.Colors.ink.color)
      Text(detail).fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color).multilineTextAlignment(.center)
    }
  }
}
