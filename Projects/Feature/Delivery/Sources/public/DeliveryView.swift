import SwiftUI
import UIKit

import Domain
import UIComponent

/// 전달 링크 발급/관리 화면 — 암호 기본 ON, 예약공개, revoke.
public struct DeliveryView: View {
  @State private var model: DeliveryModelData
  private let linkBaseURL: String
  /// 이 편지를 뷰어로 미리보기(라우팅 레이어가 주입).
  private let onPreview: () -> Void

  public init(letterId: String, deliveryUsecase: DeliveryUsecasable, linkBaseURL: String, onPreview: @escaping () -> Void) {
    _model = State(initialValue: DeliveryModelData(letterId: letterId, deliveryUsecase: deliveryUsecase))
    self.linkBaseURL = linkBaseURL
    self.onPreview = onPreview
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("링크로 보내기").fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)

          MutterButton("편지 미리보기", style: .ghost) { onPreview() }

          issueCard
          if let token = model.lastIssuedToken { issuedLink(token) }
          if !model.links.isEmpty { existingLinks }

          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
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
        Text("암호 보호").fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
      }
      .tint(Asset.Colors.gold.color)
      if model.usePassword {
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }

      Toggle(isOn: $model.useReveal) {
        Text("예약 공개").fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
      }
      .tint(Asset.Colors.gold.color)
      if model.useReveal {
        DatePicker("공개 시각", selection: $model.revealAt, in: Date()...)
          .datePickerStyle(.compact)
      }

      MutterButton("링크 발급", isLoading: model.isLoading, isEnabled: model.canIssue) {
        Task { await model.issue() }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }

  private func issuedLink(_ token: String) -> some View {
    let link = "\(linkBaseURL)/l/\(token)"
    return HStack {
      Text(link).fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color).lineLimit(1)
      Spacer()
      Button {
        UIPasteboard.general.string = link
      } label: {
        MutterIcon(Asset.Images.copy, size: 20).foregroundStyle(Asset.Colors.gold.color)
      }
    }
    .padding(12)
    .background(Asset.Colors.goldSoft.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }

  private var existingLinks: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("발급된 링크").fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.inkSoft.color)
      ForEach(model.links) { link in
        HStack(spacing: 10) {
          MutterIcon(link.hasPassword ? Asset.Images.lock : Asset.Images.link, size: 18)
            .foregroundStyle(link.revoked ? Asset.Colors.inkFaint.color : Asset.Colors.gold.color)
          VStack(alignment: .leading, spacing: 2) {
            Text(String(link.token.prefix(10)) + "…")
              .fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color)
            if link.revoked {
              Text("무효화됨").fonts(.caption).foregroundStyle(Asset.Colors.inkFaint.color)
            }
          }
          Spacer()
          if !link.revoked {
            Button("무효화") { Task { await model.revoke(link.token) } }
              .fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .padding(14)
        .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }
    }
  }
}
