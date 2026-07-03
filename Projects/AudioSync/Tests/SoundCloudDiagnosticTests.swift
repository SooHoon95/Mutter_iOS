import XCTest
import SwiftUI

@testable import AudioSync

/// SC 위젯 파이프라인 격리 진단 — 실제 네트워크로 SC 공식 데모 트랙(위젯 API 문서 예제)을 로드해
/// READY 수신 여부를 검증한다. 실패하면 위젯 임베드 구조 자체의 문제(HTML/브리지/정책),
/// 성공하면 특정 트랙의 임베드 가능 여부/기기 환경 문제로 좁혀진다.
@MainActor
final class SoundCloudDiagnosticTests: XCTestCase {

  func test_SC위젯_데모트랙_READY수신() async throws {
    let source = SoundCloudSource(
      trackURL: URL(string: "https://soundcloud.com/forss/flickermood")!
    )

    // WKWebView는 실제 뷰 계층에 있어야 로드된다 — 테스트 윈도우에 마운트.
    guard let attachment = source.attachmentView else {
      return XCTFail("SC 소스는 attachmentView가 있어야 한다")
    }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    window.rootViewController = UIHostingController(rootView: attachment)
    window.makeKeyAndVisible()

    // READY까지 대기(내부 10s 타임아웃 → throw = 위젯 미로드).
    try await source.load()
  }
}
