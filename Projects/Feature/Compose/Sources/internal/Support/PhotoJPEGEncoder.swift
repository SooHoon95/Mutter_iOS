import UIKit

/// 고른 사진을 업로드용 JPEG로 줄인다(세 플랫폼 공통: 긴 변 2048px, 품질 0.8).
/// 원본(수십 MB HEIC 등)을 그대로 올리지 않도록 기기에서 먼저 처리한다.
enum PhotoJPEGEncoder {
  struct Output {
    let jpeg: Data
    let width: Int
    let height: Int
  }

  static let maxLongSide: CGFloat = 2048
  static let quality: CGFloat = 0.8

  /// 디코딩·리사이즈는 무거우므로 메인 스레드 밖에서 호출한다.
  static func encode(_ data: Data) -> Output? {
    guard let image = UIImage(data: data) else { return nil }
    // image.size는 EXIF 회전이 반영된 포인트 크기 — 렌더러가 회전을 적용해 그리므로 결과는 똑바로 선다.
    let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    let longSide = max(pixelSize.width, pixelSize.height)
    guard longSide > 0 else { return nil }
    let ratio = min(1, maxLongSide / longSide)
    let target = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1        // target을 픽셀 단위로 쓰기 위해 화면 배율을 끈다.
    format.opaque = true    // JPEG엔 알파가 없다.
    let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
    guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
    return Output(jpeg: jpeg, width: Int(target.width), height: Int(target.height))
  }
}
