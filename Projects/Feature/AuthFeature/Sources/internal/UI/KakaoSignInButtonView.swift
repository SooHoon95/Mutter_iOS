import SwiftUI

import UIComponent

/// 카카오 로그인 버튼(Mercury 대응). 카카오 옐로우 캡슐.
struct KakaoSignInButtonView: View {
  var completion: () async -> Void

  var body: some View {
    Button {
      Task { await completion() }
    } label: {
      ZStack {
        Text(L10n.authKakao)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.ink.color)
        HStack {
          Asset.Images.kakao.image
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .padding(.leading, 5)
          Spacer()
        }
      }
      .frame(height: 52)
      .padding(.horizontal, 20)
      .background(.yellow)
      .clipShape(Capsule())
    }
  }
}
