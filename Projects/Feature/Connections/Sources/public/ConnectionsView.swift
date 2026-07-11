import SwiftUI
import UIKit

import Domain
import UIComponent

/// 연결 탭 — N:N 연결 목록 / 초대 링크 / 특정 연결 해제.
public struct ConnectionsView: View {
  @State private var model: ConnectionsModelData
  @State private var disconnectTarget: Connection?
  @Environment(\.scenePhase) private var scenePhase

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

          if !model.connections.isEmpty {
            connectionsCard
          }
          inviteCard

          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .padding(24)
        .frame(maxWidth: 520)
      }
    }
    .task { await model.load() }
    // 앱 포그라운드 복귀 시 재로드 — 상대가 연결을 끊었을 때 최신 상태 반영 (EC-2.5).
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active { Task { await model.load() } }
    }
    .confirmationDialog(
      "연결을 해제할까요?",
      isPresented: Binding(get: { disconnectTarget != nil }, set: { if !$0 { disconnectTarget = nil } }),
      titleVisibility: .visible,
      presenting: disconnectTarget
    ) { target in
      Button("해제", role: .destructive) { Task { await model.disconnect(otherUserId: target.userId) } }
      Button("취소", role: .cancel) {}
    } message: { _ in
      Text("편지와 받은함은 남지만 서로에게 더는 보낼 수 없어요.")
    }
  }

  /// 연결된 사람 목록(N:N). 각 행에서 개별 해제.
  private var connectionsCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("연결된 사람")
        .fonts(.bodyLargeBold).foregroundStyle(Asset.Colors.ink.color)
      ForEach(model.connections) { connection in
        HStack(spacing: 12) {
          MutterIcon(Asset.Images.connect, size: 22).foregroundStyle(Asset.Colors.gold.color)
          Text(connection.nickname ?? "연결된 사람")
            .fonts(.bodyMedium).foregroundStyle(Asset.Colors.ink.color)
          Spacer()
          Button("해제") { disconnectTarget = connection }
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.goldDeep.color)
        }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }

  /// 초대 링크 — N:N이라 연결이 있어도 항상 노출(더 연결하기).
  private var inviteCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.connections.isEmpty ? "아직 연결된 사람이 없어요" : "다른 사람과 더 연결하기")
        .fonts(.bodyLargeBold).foregroundStyle(Asset.Colors.ink.color)
      Text("초대 링크를 보내 연결하세요.")
        .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)

      if let token = model.inviteToken {
        // from=app — 앱 발급 링크. 수신자에게 앱이 없으면 웹 랜딩이 App Store로 안내(웹 발급은 웹 폴백).
        let link = "\(inviteBaseURL)/connect/\(token)?from=app"
        HStack(spacing: 16) {
          Text(link).fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color).lineLimit(1)
          Spacer()
          Button {
            UIPasteboard.general.string = link
          } label: {
            MutterIcon(Asset.Images.copy, size: 20).foregroundStyle(Asset.Colors.gold.color)
          }
          // 네이티브 공유 시트 — 메시지·카톡 등으로 초대 링크 바로 전달(복사 병기).
          ShareLink(item: link) {
            MutterIcon(Asset.Images.share, size: 20).foregroundStyle(Asset.Colors.gold.color)
          }
        }
        .padding(12)
        .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))

        // 초대가 아직 수락되지 않은 경우 취소할 수 있다 (EC-2.8).
        MutterButton("초대 취소", style: .ghost, isLoading: model.isLoading) {
          Task { await model.revokeInvite() }
        }
      } else {
        MutterButton("초대 링크 만들기", isLoading: model.isLoading) {
          Task { await model.createInvite() }
        }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }
}
