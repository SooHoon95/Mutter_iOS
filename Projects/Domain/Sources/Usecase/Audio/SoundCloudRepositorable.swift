import Foundation

/// SoundCloud oEmbed 검증 저장소 — 붙여넣은 트랙 URL의 임베드 가능 여부를 확인하고
/// 위젯이 재생할 수 있는 canonical URL로 변환한다. 구현: Infrastructure `SoundCloudRepository`.
public protocol SoundCloudRepositorable {
  func validate(url: String) async -> ScValidation
}
