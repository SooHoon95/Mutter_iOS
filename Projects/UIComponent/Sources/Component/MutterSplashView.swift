import SwiftUI

import Lottie

/// 앱 스플래시 — Lottie(`MutterSplash.json`)를 아이보리 배경에 1회 재생한다.
/// Mercury `MercuryLoadingView`의 `LottieView(an imation:.named(_, bundle: .module))` 패턴을 그대로 따른다.
/// (리소스: `UIComponent/Resources/Lotties/MutterSplash.json` → 프레임워크 번들 `.module`.)
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
