import SwiftUI

import Domain
import UIComponent

/// 권리침해 신고 폼.
struct TakedownView: View {
  @State private var model: TakedownModelData

  init(takedownUsecase: TakedownUsecasable) {
    _model = State(initialValue: TakedownModelData(takedownUsecase: takedownUsecase))
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      if model.submitted {
        submittedView
      } else {
        form
      }
    }
  }

  private var form: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("권리침해 신고")
          .fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)
        Text("저작권 등 권리침해를 신고하시면 신속히 검토합니다.")
          .fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)

        field("성명/단체", text: $model.claimant)
        field("연락처(이메일)", text: $model.contact)
        field("신고 대상(링크/트랙, 선택)", text: $model.trackRef)

        VStack(alignment: .leading, spacing: 8) {
          Text("사유").fonts(.captionBold).foregroundStyle(Asset.Colors.inkSoft.color)
          TextEditor(text: $model.reason)
            .frame(minHeight: 120)
            .padding(8)
            .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
        }

        MutterButton("신고 접수", isLoading: model.isLoading, isEnabled: model.isValid) {
          Task { await model.submit() }
        }
      }
      .padding(24)
      .frame(maxWidth: 520)
    }
  }

  private var submittedView: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 36)).foregroundStyle(Asset.Colors.gold.color)
      Text("신고가 접수됐어요").fonts(.title).foregroundStyle(Asset.Colors.ink.color)
      Text("검토 후 연락처로 안내드립니다.").fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)
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
