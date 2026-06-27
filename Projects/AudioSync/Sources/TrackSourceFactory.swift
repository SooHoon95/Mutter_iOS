import Foundation

import Domain

/// 재생 사양(`TrackSourceSpec`)에서 적절한 `TrackSource` 구현을 만든다.
/// 싱크 엔진은 이 팩토리만 거치고 구체 타입을 모른다.
enum TrackSourceFactory {
  @MainActor
  static func make(spec: TrackSourceSpec) -> TrackSource {
    switch spec {
    case .hosted(let url, let startMs):
      return HostedAudioSource(url: url, startMs: startMs ?? 0)
    case .soundcloud(let trackURL, let startMs):
      return SoundCloudSource(trackURL: trackURL, startMs: startMs ?? 0)
    }
  }
}
