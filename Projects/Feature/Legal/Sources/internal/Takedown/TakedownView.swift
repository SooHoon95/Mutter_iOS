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
      MutterColor.ivory.ignoresSafeArea()
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
          .fonts(.titleLarge).foregroundStyle(MutterColor.ink)
        Text("저작권 등 권리침해를 신고하시면 신속히 검토합니다.")
          .fonts(.bodyMedium).foregroundStyle(MutterColor.inkSoft)

        field("성명/단체", text: $model.claimant)
        field("연락처(이메일)", text: $model.contact)
        field("신고 대상(링크/트랙, 선택)", text: $model.trackRef)

        VStack(alignment: .leading, spacing: 8) {
          Text("사유").fonts(.captionBold).foregroundStyle(MutterColor.inkSoft)
          TextEditor(text: $model.reason)
            .frame(minHeight: 120)
            .padding(8)
            .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        }

        if let message = model.errorMessage {
          Text(message).fonts(.caption).foregroundStyle(MutterColor.goldDeep)
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
        .font(.system(size: 36)).foregroundStyle(MutterColor.gold)
      Text("신고가 접수됐어요").fonts(.title).foregroundStyle(MutterColor.ink)
      Text("검토 후 연락처로 안내드립니다.").fonts(.bodyMedium).foregroundStyle(MutterColor.inkSoft)
    }
    .padding(32)
  }

  private func field(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .textFieldStyle(.plain)
      .padding(14)
      .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.md))
  }
}
