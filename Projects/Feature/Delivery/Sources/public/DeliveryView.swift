import SwiftUI
import UIKit

import Domain
import UIComponent

/// 전달 링크 발급/관리 화면 — 암호 기본 ON, 예약공개, revoke.
public struct DeliveryView: View {
  @State private var model: DeliveryModelData
  private let linkBaseURL: String

  public init(letterId: String, deliveryUsecase: DeliveryUsecasable, linkBaseURL: String) {
    _model = State(initialValue: DeliveryModelData(letterId: letterId, deliveryUsecase: deliveryUsecase))
    self.linkBaseURL = linkBaseURL
  }

  public var body: some View {
    ZStack {
      MutterColor.ivory.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("링크로 보내기").fonts(.titleLarge).foregroundStyle(MutterColor.ink)

          issueCard
          if let token = model.lastIssuedToken { issuedLink(token) }
          if !model.links.isEmpty { existingLinks }

          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(MutterColor.goldDeep)
          }
        }
        .padding(24)
        .frame(maxWidth: 560)
      }
    }
    .task { await model.load() }
  }

  private var issueCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle(isOn: $model.usePassword) {
        Text("암호 보호").fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink)
      }
      .tint(MutterColor.gold)
      if model.usePassword {
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
          .padding(12)
          .background(MutterColor.ivory, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }

      Toggle(isOn: $model.useReveal) {
        Text("예약 공개").fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink)
      }
      .tint(MutterColor.gold)
      if model.useReveal {
        DatePicker("공개 시각", selection: $model.revealAt, in: Date()...)
          .datePickerStyle(.compact)
      }

      MutterButton("링크 발급", isLoading: model.isLoading, isEnabled: model.canIssue) {
        Task { await model.issue() }
      }
    }
    .padding(20)
    .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.soft)
  }

  private func issuedLink(_ token: String) -> some View {
    let link = "\(linkBaseURL)/l/\(token)"
    return HStack {
      Text(link).fonts(.caption).foregroundStyle(MutterColor.inkMid).lineLimit(1)
      Spacer()
      Button {
        UIPasteboard.general.string = link
      } label: {
        Image(systemName: "doc.on.doc").foregroundStyle(MutterColor.gold)
      }
    }
    .padding(12)
    .background(MutterColor.goldSoft, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }

  private var existingLinks: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("발급된 링크").fonts(.bodyMediumBold).foregroundStyle(MutterColor.inkSoft)
      ForEach(model.links) { link in
        HStack(spacing: 10) {
          Image(systemName: link.hasPassword ? "lock.fill" : "link")
            .foregroundStyle(link.revoked ? MutterColor.inkFaint : MutterColor.gold)
          VStack(alignment: .leading, spacing: 2) {
            Text(String(link.token.prefix(10)) + "…")
              .fonts(.caption).foregroundStyle(MutterColor.inkMid)
            if link.revoked {
              Text("무효화됨").fonts(.caption).foregroundStyle(MutterColor.inkFaint)
            }
          }
          Spacer()
          if !link.revoked {
            Button("무효화") { Task { await model.revoke(link.token) } }
              .fonts(.captionBold).foregroundStyle(MutterColor.goldDeep)
          }
        }
        .padding(14)
        .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }
    }
  }
}
