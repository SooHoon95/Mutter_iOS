import SwiftUI
import UIKit

import Domain
import UIComponent

/// 전달 링크 발급/관리 화면 — 암호 기본 ON, 예약공개, revoke.
public struct DeliveryView: View {
  @State private var model: DeliveryModelData
  private let linkBaseURL: String
  private let navTitle: String
  /// 이 편지를 뷰어로 미리보기(라우팅 레이어가 주입).
  private let onPreview: () -> Void
  private let onBack: () -> Void

  public init(
    letterId: String,
    deliveryUsecase: DeliveryUsecasable,
    linkBaseURL: String,
    navTitle: String,
    onPreview: @escaping () -> Void,
    onBack: @escaping () -> Void
  ) {
    _model = State(initialValue: DeliveryModelData(letterId: letterId, deliveryUsecase: deliveryUsecase))
    self.linkBaseURL = linkBaseURL
    self.navTitle = navTitle
    self.onPreview = onPreview
    self.onBack = onBack
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      // Mercury 패턴: navbar를 body 최상단 Component로 직접 배치(모디파이어 아님).
      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          navTitle,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

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
    }
    .toolbar(.hidden, for: .navigationBar)
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
            // 링크 유실 대비 — 발급된 링크를 다시 복사해 전달할 수 있게.
            Button {
              UIPasteboard.general.string = "\(linkBaseURL)/l/\(link.token)"
            } label: {
              MutterIcon(Asset.Images.copy, size: 18).foregroundStyle(Asset.Colors.gold.color)
            }
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
