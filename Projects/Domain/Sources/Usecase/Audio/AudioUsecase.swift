import Foundation

import AppFoundation

/// 오디오 유스케이스 구현 — 음원은 SoundCloud 단일(CC0 번들 제거, 무음 허용).
public final class AudioUsecase: AudioUsecasable {
  private let soundCloud: SoundCloudRepositorable

  public init(soundCloud: SoundCloudRepositorable) {
    self.soundCloud = soundCloud
  }

  public func validateSoundCloud(url: String) async -> ScValidation {
    await soundCloud.validate(url: url)
  }

  public func resolvePlayback(_ cue: MusicCue) throws -> TrackSourceSpec {
    switch cue.source {
    case .hosted:
      // 레거시 웹 편지 호환: 절대 URL만 재생(번들 카탈로그는 제거됨). 상대경로는 재생 불가 → 무음.
      guard let url = URL(string: cue.ref), url.scheme != nil else {
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
