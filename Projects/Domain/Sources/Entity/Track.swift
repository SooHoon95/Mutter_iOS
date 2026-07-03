import Foundation

/// 재생 엔진(AudioSync)이 소비하는 재생 사양. Usecase가 `MusicCue`를 이걸로 해석한다.
/// 싱크 엔진은 출처 타입을 모른 채 이 사양만 받는다(단일 `TrackSource` 추상화).
public enum TrackSourceSpec: Equatable {
  /// 호스팅 오디오 — `AVPlayer` 직접 재생.
  case hosted(url: URL, startMs: Int?)
  /// SoundCloud — WKWebView + Widget API.
  case soundcloud(trackURL: URL, startMs: Int?)
}
