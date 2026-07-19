import SwiftUI

import UIComponent

/// 강제 업데이트 안내 팝업. 딤 배경 위 중앙 카드로 띄우며, 배경이 하단 화면과의 상호작용을
/// 물리적으로 차단한다(닫기 수단 없음 → 사실상 강제). 부정적 인상을 줄이려 경고 아이콘 대신 앱 로고를 쓴다.
struct ForceUpdateView: View {
  @Environment(\.openURL) private var openURL

  /// 뮤터 App Store 제품 페이지(id 6790086549).
  private let appStoreURL = URL(string: "https://apps.apple.com/kr/app/id6790086549")

  var body: some View {
    ZStack {
      // 딤 스크림 — 하단 화면을 가리고 상호작용을 차단한다.
      Color.black.opacity(0.45)
        .ignoresSafeArea()

      // 중앙 팝업 카드
      VStack(spacing: 18) {
        Asset.Images.onboardingLogo.image
          .resizable()
          .scaledToFit()
          .frame(height: 64)

        Text(L10n.forceUpdateTitle)
          .fonts(.title)
          .foregroundStyle(Asset.Colors.ink.color)
          .multilineTextAlignment(.center)

        Text(L10n.forceUpdateDetail)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.inkSoft.color)
          .multilineTextAlignment(.center)

        MutterButton(L10n.forceUpdateButton) {
          if let url = appStoreURL { openURL(url) }
        }
        .padding(.top, 4)
      }
      .padding(28)
      .frame(maxWidth: 360)
      .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.xl))
      .shadows(.shadowLow)
      .padding(32)
    }
  }
}
