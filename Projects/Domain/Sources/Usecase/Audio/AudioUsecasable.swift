import Foundation

/// 오디오 유스케이스 — 기본 큐 제공 + 큐→재생사양 해석.
/// (싱크 엔진이 출처를 모르게 하는 `TrackSource` 추상화의 입력을 만든다.)
public protocol AudioUsecasable {
  /// 첫 CC0 기반 기본 큐(무음0 폴백).
  func defaultCue() async throws -> MusicCue
  /// 큐를 재생 사양으로 해석(hosted→url, soundcloud→widget). 순수 변환.
  func resolvePlayback(_ cue: MusicCue) throws -> TrackSourceSpec
}
