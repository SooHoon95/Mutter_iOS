import SwiftUI

import UIComponent

/// 구글 로그인 버튼(Mercury 대응). 흰 배경 + 테두리 캡슐.
struct GoogleSignInButtonView: View {
  var completion: () async -> Void

  var body: some View {
    Button {
      Task { await completion() }
    } label: {
      ZStack {
        Text("Google로 계속")
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.ink.color)
        HStack(spacing: 0) {
          Asset.Images.google.image
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
          Spacer()
        }
      }
      .frame(height: 52)
      .padding(.horizontal, 20)
      .background(.white)
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .strokeBorder(Asset.Colors.hairlineStrong.color, lineWidth: 1)
      }
    }
  }
}
