import Foundation

/// 오디오 유스케이스 — 기본 큐 제공 + 큐→재생사양 해석.
/// (싱크 엔진이 출처를 모르게 하는 `TrackSource` 추상화의 입력을 만든다.)
public protocol AudioUsecasable {
  /// 큐를 재생 사양으로 해석(hosted→url, soundcloud→widget). 순수 변환.
  func resolvePlayback(_ cue: MusicCue) throws -> TrackSourceSpec
  /// SC paste-URL을 oEmbed로 검증(붙이는 시점) — 단축링크→canonical 변환 포함.
  /// 재생 시점 폴백에만 맡기면 발신자가 죽은 링크를 모른 채 보내게 된다.
  func validateSoundCloud(url: String) async -> ScValidation
}
