import SwiftUI

import Domain
import UIComponent

/// 권리침해 신고 폼.
struct TakedownView: View {
  @State private var model: TakedownModelData
  private let onBack: () -> Void

  init(takedownUsecase: TakedownUsecasable, onBack: @escaping () -> Void) {
    self.onBack = onBack
    _model = State(initialValue: TakedownModelData(takedownUsecase: takedownUsecase))
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      // Mercury 패턴: navbar를 body 최상단 Component로 직접 배치(모디파이어 아님).
      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          L10n.legalContact,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        if model.submitted {
          submittedView
        } else {
          form
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private var form: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(L10n.takedownTitle)
          .fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)
        Text(L10n.takedownSubtitle)
          .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)

        field(L10n.takedownFieldClaimant, text: $model.claimant)
        field(L10n.takedownFieldContact, text: $model.contact)
        field(L10n.takedownFieldTarget, text: $model.trackRef)

        VStack(alignment: .leading, spacing: 8) {
          Text(L10n.takedownFieldReason).fonts(.captionBold).foregroundStyle(Asset.Colors.inkSoft.color)
          TextEditor(text: $model.reason)
            .frame(minHeight: 120)
            .padding(8)
            .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
        }

        MutterButton(L10n.takedownSubmit, isLoading: model.isLoading, isEnabled: model.isValid) {
          Task { await model.submit() }
        }
      }
      .padding(24)
      .frame(maxWidth: 520)
    }
  }

  private var submittedView: some View {
    VStack(spacing: 12) {
      MutterIcon(Asset.Images.checkCircle, size: 44)
        .foregroundStyle(Asset.Colors.gold.color)
      Text(L10n.takedownDoneTitle).fonts(.title).foregroundStyle(Asset.Colors.ink.color)
      Text(L10n.takedownDoneDetail).fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)
    }
    .padding(32)
  }

  private func field(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .textFieldStyle(.plain)
      .padding(14)
      .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }
}
