import SwiftUI

import Lottie

/// 앱 스플래시 — Lottie(`SplashAnimation.json`)를 아이보리 배경에 1회 재생한다.
/// Mercury `MercuryLoadingView`의 `LottieView(animation:.named(_, bundle: .module))` 패턴을 그대로 따른다.
/// (리소스: `UIComponent/Resources/Lotties/SplashAnimation.json` → 프레임워크 번들 `.module`.)
/// 0프레임은 런치 이미지(`LaunchImage`)와 같은 그림이다. 둘 다 `scripts/splash/build_splash_lottie.py`에서 나온다 —
/// 봉투 위치·색을 바꾸면 런치 이미지도 0프레임으로 다시 뽑아야 넘어올 때 튀지 않는다.
public struct MutterSplashView: View {
  public init() {}
  
  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      GeometryReader { geometry in
        LottieView(animation: .named("SplashAnimation", bundle: .module))
          .configure { lottieAnimationView in
            lottieAnimationView.contentMode = .scaleAspectFit
            lottieAnimationView.shouldRasterizeWhenIdle = true
          }
          .playing(loopMode: .playOnce)
          .resizable()
          .scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
      }
      
    }
    .ignoresSafeArea()
  }
}
