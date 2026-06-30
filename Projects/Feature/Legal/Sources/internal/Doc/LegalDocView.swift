import SwiftUI

import UIComponent

/// 약관/개인정보처리방침 등 정적 문서 화면.
struct LegalDocView: View {
  let title: String
  let text: String

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
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
}
