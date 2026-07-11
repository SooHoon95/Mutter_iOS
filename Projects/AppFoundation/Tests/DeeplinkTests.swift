import XCTest

@testable import AppFoundation

/// `Deeplink.init?(url:)` 파싱 매트릭스 — 스킴({https, mutter, 그 외}) × 키워드({l, connect, 미지원}) × 토큰 유무.
/// 목표: 커스텀 스킴(`mutter://`) 지원, 기존 Universal Link(`https://`) 동작 보존, OAuth·기타 스킴 배제(AC6).
final class DeeplinkTests: XCTestCase {

  private func deeplink(_ string: String) -> Deeplink? {
    guard let url = URL(string: string) else {
      XCTFail("테스트 URL 문자열이 유효하지 않음: \(string)")
      return nil
    }
    return Deeplink(url: url)
  }

  // MARK: - 정상 파싱

  func test_https_connect_파싱() {
    XCTAssertEqual(
      deeplink("https://letter-app-nine-kohl.vercel.app/connect/T"),
      .connect(token: "T")
    )
  }

  func test_https_letter_파싱() {
    XCTAssertEqual(
      deeplink("https://letter-app-nine-kohl.vercel.app/l/T"),
      .letter(token: "T")
    )
  }

  func test_mutter_connect_파싱() {
    XCTAssertEqual(deeplink("mutter://connect/T"), .connect(token: "T"))
  }

  func test_mutter_letter_파싱() {
    XCTAssertEqual(deeplink("mutter://l/T"), .letter(token: "T"))
  }

  // MARK: - 출처 쿼리(?from=app/web) 무영향 — 토큰 파싱은 쿼리를 무시(초대링크 출처 인코딩)

  func test_https_connect_from쿼리_토큰만파싱() {
    XCTAssertEqual(
      deeplink("https://letter-app-nine-kohl.vercel.app/connect/T?from=app"),
      .connect(token: "T")
    )
    XCTAssertEqual(
      deeplink("https://letter-app-nine-kohl.vercel.app/connect/T?from=web"),
      .connect(token: "T")
    )
  }

  func test_mutter_connect_from쿼리_토큰만파싱() {
    XCTAssertEqual(deeplink("mutter://connect/T?from=app"), .connect(token: "T"))
  }

  // MARK: - nil(파싱 불가)

  func test_mutter_토큰없음_nil() {
    XCTAssertNil(deeplink("mutter://connect"))
  }

  func test_https_토큰없음_nil() {
    XCTAssertNil(deeplink("https://letter-app-nine-kohl.vercel.app/connect"))
  }

  func test_ftp_스킴_nil() {
    XCTAssertNil(deeplink("ftp://connect/T"))
  }

  func test_mutter_미지원키워드_nil() {
    XCTAssertNil(deeplink("mutter://unknown/T"))
  }

  func test_kakao_oauth_콜백스킴_nil() {
    // 실제 카카오 로그인 콜백 스킴(kakao{appKey}://oauth) — 화이트리스트 밖이라 무영향.
    XCTAssertNil(deeplink("kakao1a2b3c4d5e://oauth"))
  }

  func test_google_역방향클라이언트ID_스킴_nil() {
    // 구글 OAuth 리다이렉트(reversed client id) 스킴 — 화이트리스트 밖이라 무영향.
    XCTAssertNil(deeplink("com.googleusercontent.apps.abc123://redirect"))
  }
}
