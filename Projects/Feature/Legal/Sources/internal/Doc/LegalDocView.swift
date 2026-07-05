import SwiftUI

import UIComponent

/// 약관/개인정보처리방침 등 정적 문서 화면.
struct LegalDocView: View {
  let title: String
  let text: String
  private let onBack: () -> Void

  init(title: String, text: String, onBack: @escaping () -> Void) {
    self.title = title
    self.text = text
    self.onBack = onBack
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      // Mercury 패턴: navbar를 body 최상단 Component로 직접 배치(모디파이어 아님).
      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          title,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(title).fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)
            Text(text).fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkMid.color)
          }
          .padding(24)
          .frame(maxWidth: 600, alignment: .leading)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }
}
