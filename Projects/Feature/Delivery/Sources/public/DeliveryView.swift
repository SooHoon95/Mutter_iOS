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
            Text(L10n.deliveryLinkSend).fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)

            MutterButton(L10n.deliveryPreview, style: .ghost) { onPreview() }

            issueCard
            if let link = model.lastIssuedLink { issuedLink(link) }
            if !model.links.isEmpty { existingLinks }

            if let message = model.errorMessage {
              Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
            }
          }
          .padding(24)
          .frame(maxWidth: 560)
        }
        .refreshable { await model.load() }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task { await model.load() }
  }

  private var issueCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle(isOn: $model.usePassword) {
        Text(L10n.sendPasswordTitle).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
      }
      .tint(Asset.Colors.gold.color)
      if model.usePassword {
        SecureField(L10n.commonPassword, text: $model.password)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Asset.Colors.ivory.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }

      Toggle(isOn: $model.useReveal) {
        Text(L10n.deliveryReveal).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color)
      }
      .tint(Asset.Colors.gold.color)
      if model.useReveal {
        DatePicker(L10n.deliveryRevealAt, selection: $model.revealAt, in: Date()...)
          .datePickerStyle(.compact)
      }

      MutterButton(L10n.deliveryIssue, isLoading: model.isLoading, isEnabled: model.canIssue) {
        Task { await model.issue() }
      }
    }
    .padding(20)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
    .shadows(.shadowLow)
  }

  private func linkURL(_ token: String) -> String { "\(linkBaseURL)/l/\(token)" }

  /// 네이티브 공유 시트 — 동봉 문구(암호·예약 반영) + 링크. 복사 버튼과 병기한다.
  private func shareIcon(_ link: DeliveryLink, size: CGFloat) -> some View {
    ShareLink(
      item: LetterShareMessage.text(url: linkURL(link.token), hasPassword: link.hasPassword, revealAt: link.revealAt)
    ) {
      MutterIcon(Asset.Images.share, size: size).foregroundStyle(Asset.Colors.gold.color)
    }
    .accessibilityLabel(L10n.sendShare)
  }

  private func issuedLink(_ link: DeliveryLink) -> some View {
    let url = linkURL(link.token)
    return HStack(spacing: 16) {
      Text(url).fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color).lineLimit(1)
      Spacer()
      Button {
        UIPasteboard.general.string = url
      } label: {
        MutterIcon(Asset.Images.copy, size: 20).foregroundStyle(Asset.Colors.gold.color)
      }
      shareIcon(link, size: 20)
    }
    .padding(12)
    .background(Asset.Colors.goldSoft.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }

  private var existingLinks: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.deliveryIssued).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.inkSoft.color)
      ForEach(model.links) { link in
        HStack(spacing: 10) {
          MutterIcon(link.hasPassword ? Asset.Images.lock : Asset.Images.link, size: 18)
            .foregroundStyle(link.revoked ? Asset.Colors.inkFaint.color : Asset.Colors.gold.color)
          VStack(alignment: .leading, spacing: 2) {
            Text(String(link.token.prefix(10)) + "…")
              .fonts(.caption).foregroundStyle(Asset.Colors.inkMid.color)
            if link.revoked {
              Text(L10n.deliveryRevoked).fonts(.caption).foregroundStyle(Asset.Colors.inkFaint.color)
            }
          }
          Spacer()
          if !link.revoked {
            // 링크 유실 대비 — 발급된 링크를 다시 복사·공유해 전달할 수 있게.
            Button {
              UIPasteboard.general.string = linkURL(link.token)
            } label: {
              MutterIcon(Asset.Images.copy, size: 18).foregroundStyle(Asset.Colors.gold.color)
            }
            shareIcon(link, size: 18)
            Button(L10n.deliveryRevoke) { Task { await model.revoke(link.token) } }
              .fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .padding(14)
        .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
      }
    }
  }
}
