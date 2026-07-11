import SwiftUI

import Lottie

/// 온보딩 등에서 쓰는 로고 마크 — **스플래시와 동일한 Lottie(`SplashAnimation`)** 를 정사각으로 1회 재생.
/// 스플래시 컴포지션(1080×1920, 아이보리 배경)을 center-crop(scaleAspectFill)해 로고만 보이게 한다.
/// 배경이 온보딩과 같은 `ivory`라 자연스럽게 섞인다. (별도 정적 로고 에셋이 없어 Lottie를 그대로 씀.)
public struct MutterLogoMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 120) {
    self.size = size
  }

  public var body: some View {
   
  }
}
