import XCTest

@testable import Infrastructure
import Domain

final class InfrastructureTests: XCTestCase {
  // MARK: - MU-1: 트랙 title/author 지속(paragraphs jsonb 왕복)

  /// oEmbed로 받은 트랙 title/author가 본문+cue → paragraphs jsonb → cue 왕복에서 보존되는지.
  /// (뷰어 플레이어 바가 편지 제목이 아니라 트랙 제목을 표시하는 것의 지속 계약.)
  func test_letterContentCodec_preservesCueTitleAuthor() {
    let cue = MusicCue(
      source: .soundcloud,
      ref: "https://soundcloud.com/artist/track",
      startMs: 1500,
      title: "Flickermood",
      author: "Forss"
    )

    let paragraphs = LetterContentCodec.paragraphs(body: "첫 단락\n\n둘째 단락", cue: cue)
    let restored = LetterContentCodec.cue(from: paragraphs)

    XCTAssertEqual(restored?.title, "Flickermood")
    XCTAssertEqual(restored?.author, "Forss")
    XCTAssertEqual(restored?.ref, "https://soundcloud.com/artist/track")
    XCTAssertEqual(restored?.startMs, 1500)
  }

  /// 레거시/웹 생성 편지(title·author 키가 없는 jsonb)는 nil로 안전 디코드 → 뷰어 폴백 경로.
  func test_letterContentCodec_legacyCueDecodesNilTitleAuthor() throws {
    let legacyJSON = Data("""
    [{"id":"1","order":0,"text":"본문","cue":{"sourceType":"soundcloud","ref":"https://soundcloud.com/x","startMs":0}}]
    """.utf8)

    let paragraphs = try JSONDecoder().decode([ParagraphDTO].self, from: legacyJSON)
    let cue = LetterContentCodec.cue(from: paragraphs)

    XCTAssertNil(cue?.title)
    XCTAssertNil(cue?.author)
    XCTAssertEqual(cue?.ref, "https://soundcloud.com/x")
  }
}
