import SwiftUI

/// 편지 속 사진 한 장. 원본 비율로 자리를 먼저 잡고, 이미지가 오면 채운다.
/// URL이 없거나 받지 못하면 차분한 플레이스홀더를 그대로 둔다(본문 흐름은 깨지 않는다).
public struct LetterPhotoView: View {
  private let url: URL?
  private let cacheKey: String?
  private let localImage: UIImage?
  private let aspectRatio: CGFloat
  private let tint: Color

  /// - Parameters:
  ///   - localImage: 아직 업로드하지 않은 사진(제작 화면). 있으면 네트워크 없이 바로 그린다.
  ///   - aspectRatio: 가로/세로. 0 이하이면 4:3으로 둔다(크기 정보가 없는 데이터 방어).
  ///   - tint: 플레이스홀더 색(편지 테마 muted 등).
  public init(url: URL?, cacheKey: String?, localImage: UIImage? = nil, aspectRatio: CGFloat, tint: Color) {
    self.url = url
    self.cacheKey = cacheKey
    self.localImage = localImage
    self.aspectRatio = aspectRatio > 0 ? aspectRatio : 4.0 / 3.0
    self.tint = tint
  }

  public var body: some View {
    Color.clear
      .aspectRatio(aspectRatio, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay {
        if let localImage {
          Image(uiImage: localImage).resizable().scaledToFill()
        } else {
          CachedAsyncImage(url: url, cacheKey: cacheKey) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            placeholder
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: MutterRadius.md))
      .accessibilityElement()
      .accessibilityLabel(L10n.letterPhoto)
  }

  private var placeholder: some View {
    ZStack {
      tint.opacity(0.12)
      Image(systemName: "photo")
        .font(.system(size: 24, weight: .light))
        .foregroundStyle(tint.opacity(0.6))
    }
  }
}
