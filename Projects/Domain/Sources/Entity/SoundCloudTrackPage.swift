import Foundation

/// 인앱 SoundCloud 탐색 중 "지금 보고 있는 페이지가 트랙 한 곡인가"를 판정한다.
/// 페이지 DOM을 읽지 않고(약관상 스크래핑 금지) URL 경로 모양만으로 판단한다.
/// 트랙 페이지는 `/{user}/{track}` 2단 경로이며, 같은 2단이라도 프로필 하위 탭(`/{user}/sets` 등)은 제외한다.
public enum SoundCloudTrackPage {
  /// 트랙 페이지면 쿼리·프래그먼트·모바일 호스트를 걷어낸 공개 트랙 URL을, 아니면 nil.
  public static func trackURL(from url: URL?) -> URL? {
    guard let url,
          url.scheme == "https",
          let host = url.host?.lowercased(),
          allowedHosts.contains(host) else {
      return nil
    }

    let segments = url.path.split(separator: "/").map(String.init)
    guard segments.count == 2 else { return nil }

    let user = segments[0].lowercased()
    let slug = segments[1].lowercased()
    guard !reservedRootPaths.contains(user), !profileTabs.contains(slug) else { return nil }

    return URL(string: "https://soundcloud.com/\(segments[0])/\(segments[1])")
  }

  private static let allowedHosts: Set<String> = ["soundcloud.com", "www.soundcloud.com", "m.soundcloud.com"]

  /// 사용자명이 아닌 SoundCloud 자체 페이지(1단 경로). 2단으로 들어가도 트랙이 아니다.
  private static let reservedRootPaths: Set<String> = [
    "discover", "search", "stream", "feed", "you", "upload", "charts", "pages", "settings",
    "notifications", "messages", "terms-of-use", "legal", "pro", "mobile", "imprint", "people",
    "jobs", "popular", "tags", "stations", "signin", "signup", "logout", "connect", "artists",
    "for-artists", "creators", "premium", "go", "next", "playlists", "communities", "home"
  ]

  /// 프로필 하위 탭(`/{user}/{tab}`). 트랙 슬러그와 경로 모양이 같아 이름으로 거른다.
  private static let profileTabs: Set<String> = [
    "sets", "likes", "tracks", "albums", "reposts", "followers", "following", "popular-tracks",
    "comments", "spotlight", "recommended", "playlists", "toptracks", "station"
  ]
}
