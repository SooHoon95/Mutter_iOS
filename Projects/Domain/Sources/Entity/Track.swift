import Foundation

/// CC0/RF 큐레이션 카탈로그의 한 트랙(무음0 폴백·무드 픽커 소스).
public struct Track: Identifiable, Equatable {
  public let id: String
  public let title: String
  public let author: String
  /// 라이선스 식별자(CC0/PD/CC-BY 등 화이트리스트).
  public let license: String
  /// 호스팅 오디오 URL(Storage).
  public let url: String
  /// 무드 분류(피커 그룹핑 키).
  public let mood: String

  public init(id: String, title: String, author: String, license: String, url: String, mood: String) {
    self.id = id
    self.title = title
    self.author = author
    self.license = license
    self.url = url
    self.mood = mood
  }
}

public extension MusicCue {
  /// 카탈로그 트랙을 기본 호스팅 큐로 변환(무음0 폴백 생성에 사용).
  static func hosted(from track: Track) -> MusicCue {
    MusicCue(source: .hosted, ref: track.url, startMs: 0)
  }
}

/// 재생 엔진(AudioSync)이 소비하는 재생 사양. Usecase가 `MusicCue`를 이걸로 해석한다.
/// 싱크 엔진은 출처 타입을 모른 채 이 사양만 받는다(단일 `TrackSource` 추상화).
public enum TrackSourceSpec: Equatable {
  /// 호스팅 오디오 — `AVPlayer` 직접 재생.
  case hosted(url: URL, startMs: Int?)
  /// SoundCloud — WKWebView + Widget API.
  case soundcloud(trackURL: URL, startMs: Int?)
}
