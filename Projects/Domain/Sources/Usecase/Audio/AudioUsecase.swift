import Foundation

import AppFoundation

/// 오디오 유스케이스 구현. 카탈로그를 재사용해 기본 큐를 만든다(별도 repository 없음).
public final class AudioUsecase: AudioUsecasable {
  private let catalog: CatalogRepositorable

  public init(catalog: CatalogRepositorable) {
    self.catalog = catalog
  }

  public func defaultCue() async throws -> MusicCue {
    let tracks = try await catalog.all()
    guard let first = tracks.first else {
      throw MutterError(.server("기본 음악을 불러올 수 없어요."))
    }
    return MusicCue.hosted(from: first)
  }

  public func resolvePlayback(_ cue: MusicCue) throws -> TrackSourceSpec {
    switch cue.source {
    case .hosted:
      // 호스팅 ref는 이식가능 상대경로(`/audio/x.m4a`) — 번들 파일로 우선 해석, 없으면 원격 URL.
      guard let url = catalog.localAudioURL(for: cue.ref) ?? URL(string: cue.ref) else {
        throw MutterError(.server("재생할 음원 주소가 올바르지 않아요."))
      }
      return .hosted(url: url, startMs: cue.startMs)
    case .soundcloud:
      guard let url = URL(string: cue.ref) else {
        throw MutterError(.server("재생할 음원 주소가 올바르지 않아요."))
      }
      return .soundcloud(trackURL: url, startMs: cue.startMs)
    }
  }
}
