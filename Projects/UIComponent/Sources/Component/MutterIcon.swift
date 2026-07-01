import SwiftUI

/// 디자인 시스템 커스텀 라인 아이콘(`Asset.Images`의 템플릿 SVG)을 지정 크기로 그린다.
/// 색은 호출부에서 `.foregroundStyle(...)`로 틴팅한다(템플릿 렌더 — 기본 Ink, 포인트 Gold).
///
/// 사용: `MutterIcon(Asset.Images.envelope, size: 20).foregroundStyle(Asset.Colors.gold.color)`
public struct MutterIcon: View {
  private let asset: ImageAsset
  private let size: CGFloat

  public init(_ asset: ImageAsset, size: CGFloat = 20) {
    self.asset = asset
    self.size = size
  }

  public var body: some View {
    asset.image
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
  }
}
