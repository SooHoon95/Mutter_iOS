import Foundation

/// 편지 본문 사이에 들어가는 사진 한 장.
/// 저장된 사진은 `path`(Storage 경로)를, 아직 올리지 않은 사진은 `pendingJPEG`를 가진다.
/// 저장 흐름이 대기 사진을 업로드한 뒤 path를 채우고 pendingJPEG를 비운다.
public struct LetterPhoto: Identifiable, Equatable {
  public let id: String
  /// `<ownerId>/<letterId>/<uuid>.jpg`. nil = 아직 업로드 전.
  public var path: String?
  /// 원본 픽셀 크기 — 이미지가 오기 전에도 비율대로 자리를 잡기 위해 함께 저장한다.
  public var width: Int
  public var height: Int
  /// 업로드 대기 중인 JPEG(기기에서 이미 축소·압축된 데이터).
  public var pendingJPEG: Data?

  public init(id: String = UUID().uuidString, path: String? = nil, width: Int, height: Int, pendingJPEG: Data? = nil) {
    self.id = id
    self.path = path
    self.width = width
    self.height = height
    self.pendingJPEG = pendingJPEG
  }

  /// 편지 한 통에 넣을 수 있는 사진 수(세 플랫폼 공통 계약).
  public static let maxCount = 5
}
