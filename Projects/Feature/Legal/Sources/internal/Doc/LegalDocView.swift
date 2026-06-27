import SwiftUI

import UIComponent

/// 약관/개인정보처리방침 등 정적 문서 화면.
struct LegalDocView: View {
  let title: String
  let text: String

  var body: some View {
    ZStack {
      MutterColor.ivory.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(title).fonts(.titleLarge).foregroundStyle(MutterColor.ink)
          Text(text).fonts(.bodyMedium).foregroundStyle(MutterColor.inkMid)
        }
        .padding(24)
        .frame(maxWidth: 600, alignment: .leading)
      }
    }
  }
}
