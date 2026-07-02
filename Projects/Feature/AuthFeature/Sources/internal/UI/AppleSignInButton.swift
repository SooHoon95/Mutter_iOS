import SwiftUI

import UIComponent

/// 애플 로그인 버튼(Mercury 대응). 검은 배경 + 흰 로고/텍스트.
struct AppleSignInButton: View {
  var completion: () async -> Void

  var body: some View {
    Button {
      Task { await completion() }
    } label: {
      ZStack {
        Text("Apple로 계속")
          .fonts(.bodyMedium)
          .foregroundStyle(.white)
        HStack(spacing: 0) {
          Asset.Images.apple.image
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundStyle(.white)
          Spacer()
        }
      }
      .frame(height: 52)
      .padding(.horizontal, 20)
      .background(.black)
      .clipShape(Capsule())
    }
  }
}
