import SwiftUI
import UIKit

import Domain
import UIComponent

/// 연결 탭 — 독점 1:1 연결 상태 / 초대 링크 / 해제.
public struct ConnectionsView: View {
  @State private var model: ConnectionsModelData
  @State private var showDisconnectConfirm = false

  /// 초대 링크 베이스(예: https://mutter.app). 합성 루트가 주입.
  private let inviteBaseURL: String

  public init(connectionUsecase: ConnectionUsecasable, inviteBaseURL: String) {
    _model = State(initialValue: ConnectionsModelData(connectionUsecase: connectionUsecase))
    self.inviteBaseURL = inviteBaseURL
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("연결")
            .fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)

          if model.isConnected {
            connectedCard
          } else {
            inviteCard
          }

          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .padding(24)
        .frame(maxWidth: 520)
      }
    }
    .task { await model.load() }
    .confirmationDialog("연결을 해제할까요?", isPresented: $showDisconnectConfirm, titleVisibility: .visible) {
      Button("해제", role: .destructive) { Task { await model.disconnect() } }
      Button("취소", role: .cancel) {}
    } message: {
      Text("편지와 받은함은 남지만 서로에게 더는 보낼 수 없어요.")
    }
  }

  private var connectedCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        Image(systemName: "person.2.fill").foregroundStyle(Asset.Colors.gold.color)
        Text(model.connection?.nickname ?? "연결된 사람")
          .fonts(.bodyLargeBold).foregroundStyle(Asset.Colors.ink.color)
      }
      Text("이 사람과 1:1로 연결돼 있어요.")
        .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)
      MutterButton("연결 해제", style: .ghost) { showDisconnectConfirm = true }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.soft)
  }

  private var inviteCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("아직 연결된 사람이 없어요")
        .fonts(.bodyLargeBold).foregroundStyle(Asset.Colors.ink.color)
      Text("초대 링크를 보내 한 사람과 연결하세요.")
        .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)

      if let token = model.inviteToken {
        let link = "\(inviteBaseURL)/connect/\(token)"
        HStack {
          Text(link).fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color).lineLimit(1)
          Spacer()
          Button {
            UIPasteboard.general.string = link
          } label: {
            Image(systemName: "doc.on.doc").foregroundStyle(Asset.Colors.gold.color)
          }
        }
        .padding(12)
        .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      } else {
        MutterButton("초대 링크 만들기", isLoading: model.isLoading) {
          Task { await model.createInvite() }
        }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.soft)
  }
}
