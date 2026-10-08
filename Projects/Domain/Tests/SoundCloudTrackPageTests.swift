import XCTest

@testable import Domain

final class SoundCloudTrackPageTests: XCTestCase {
  private func track(_ raw: String) -> String? {
    SoundCloudTrackPage.trackURL(from: URL(string: raw))?.absoluteString
  }

  func test_trackPage_returnsCanonicalURL() {
    XCTAssertEqual(track("https://soundcloud.com/artist/some-song"), "https://soundcloud.com/artist/some-song")
  }

  func test_mobileHostAndQuery_areNormalized() {
    XCTAssertEqual(
      track("https://m.soundcloud.com/artist/some-song?in=artist/sets/x&utm_source=a#t=1"),
      "https://soundcloud.com/artist/some-song"
    )
  }

  func test_trailingSlash_isAccepted() {
    XCTAssertEqual(track("https://soundcloud.com/artist/some-song/"), "https://soundcloud.com/artist/some-song")
  }

  func test_profileAndTabs_areRejected() {
    XCTAssertNil(track("https://soundcloud.com/artist"))
    XCTAssertNil(track("https://soundcloud.com/artist/sets"))
    XCTAssertNil(track("https://soundcloud.com/artist/likes"))
    XCTAssertNil(track("https://soundcloud.com/artist/popular-tracks"))
  }

  func test_playlistAndPrivateShare_areRejected() {
    XCTAssertNil(track("https://soundcloud.com/artist/sets/my-playlist"))
    XCTAssertNil(track("https://soundcloud.com/artist/some-song/s-AbCdE"))
  }

  func test_reservedRootPages_areRejected() {
    XCTAssertNil(track("https://soundcloud.com/search/sounds?q=rain"))
    XCTAssertNil(track("https://soundcloud.com/discover/sets"))
    XCTAssertNil(track("https://m.soundcloud.com/you/likes"))
  }

  func test_otherHostsAndSchemes_areRejected() {
    XCTAssertNil(track("https://evil.com/artist/some-song"))
    XCTAssertNil(track("http://soundcloud.com/artist/some-song"))
    XCTAssertNil(track("https://on.soundcloud.com/abc"))
    XCTAssertNil(SoundCloudTrackPage.trackURL(from: nil))
  }
}
