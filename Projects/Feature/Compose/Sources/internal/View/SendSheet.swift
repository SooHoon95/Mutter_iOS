import SwiftUI
import UIKit

import Domain
import UIComponent

/// 저장 직후 뜨는 "보내기" 시트 — 두 방식: 전달 링크 발급 / 연결된 사람 직접 발송.
/// (Feature→Feature 의존 금지라 DeliveryView를 끌어오지 않고 Domain usecase를 직접 쓴다.)
struct SendSheet: View {
  @Bindable var model: ComposeModelData

  enum Method: String, CaseIterable, Identifiable {
    case link = "전달 링크"
    case connection = "연결된 사람"
    var id: String { rawValue }
  }
  @State private var method: Method = .link

  var body: some View {
    NavigationStack {
      ZStack {
        Asset.Colors.ivory.color.ignoresSafeArea()
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Picker("보내기 방식", selection: $method) {
              ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch method {
            case .link: linkSection
            case .connection: connectionSection
            }

            if let message = model.errorMessage {
              Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
            }
          }
          .padding(24)
          .frame(maxWidth: 560)
        }
      }
      .navigationTitle("보내기")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("닫기") { model.showSendSheet = false }
            .foregroundStyle(Asset.Colors.inkSoft.color)
        }
      }
      // 시트는 저장 성공 후에만 열리므로, 여기서 난 에러는 전부 시트發.
      // 닫힐 때 정리해 제작 화면 본문에 잔류하지 않게 한다.
      .onDisappear { model.errorMessage = nil }
    }
  }

  // MARK: - 전달 링크

  private var linkSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("아무 기기에서나 열 수 있는 전달 링크를 만들어요. 암호는 기본으로 켜져 있어요.")
        .fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color)

      Toggle(isOn: $model.usePassword) {
        Text("암호 보호").fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
      }
      .tint(Asset.Colors.gold.color)

      if model.usePassword {
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }

      MutterButton("링크 발급", isLoading: model.isIssuing, isEnabled: model.canIssueLink) {
        Task { await model.issueLink() }
      }

      if let link = model.issuedLink {
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
        .background(Asset.Colors.goldSoft.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))

        MutterButton("완료", style: .secondary) { model.finishSend() }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.soft)
  }

  // MARK: - 연결된 사람

  private var connectionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if model.connections.isEmpty {
        Text("아직 연결된 사람이 없어요. ‘전달 링크’로 보내거나, 사람들 탭에서 연결을 맺어보세요.")
          .fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color)
      } else {
        Text("연결된 사람에게 링크 없이 바로 받은 편지함으로 보내요.")
          .fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color)
        ForEach(model.connections) { connection in
          HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill").foregroundStyle(Asset.Colors.gold.color)
            Text(connection.nickname ?? "이름 없는 친구")
              .fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
            Spacer()
            Button("보내기") { Task { await model.sendToConnection(connection.userId) } }
              .fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
              .disabled(model.isSending)
          }
          .padding(14)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.soft)
  }
}
