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

    let paragraphs = LetterContentCodec.paragraphs(blocks: [.text("첫 단락\n\n둘째 단락")], cue: cue)
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

  // MARK: - 편지 사진(paragraphs.photo)

  private let cue = MusicCue(source: .soundcloud, ref: "https://soundcloud.com/a/b", startMs: 0)

  private func photo(_ id: String, path: String? = nil) -> LetterPhoto {
    LetterPhoto(id: id, path: path ?? "owner/letter/\(id).jpg", width: 1536, height: 2048)
  }

  /// 연속된 텍스트 단락은 하나의 텍스트 블록으로 합쳐지고, 사진은 order 자리에 남는다.
  func test_blocks_mergesConsecutiveTextAndKeepsPhotoPosition() throws {
    let json = Data("""
    [
      {"id":"a","order":0,"text":"하나","cue":{"sourceType":"soundcloud","ref":"r","startMs":0}},
      {"id":"b","order":1,"text":"둘"},
      {"id":"p1","order":2,"text":"","photo":{"path":"o/l/p1.jpg","width":1536,"height":2048}},
      {"id":"c","order":3,"text":"셋"},
      {"id":"p2","order":4,"text":"","photo":{"path":"o/l/p2.jpg","width":800.0,"height":600}}
    ]
    """.utf8)
    let paragraphs = try JSONDecoder().decode([ParagraphDTO].self, from: json)

    let blocks = LetterContentCodec.blocks(from: paragraphs)

    XCTAssertEqual(blocks, [
      .text("하나\n\n둘"),
      .photo(LetterPhoto(id: "p1", path: "o/l/p1.jpg", width: 1536, height: 2048)),
      .text("셋"),
      .photo(LetterPhoto(id: "p2", path: "o/l/p2.jpg", width: 800, height: 600))
    ])
    XCTAssertEqual(blocks.joinedText, "하나\n\n둘\n\n셋")
  }

  /// 저장: 텍스트 블록은 빈 줄로 나뉘고, 사진 단락은 text "" + photo, 큐는 첫 텍스트 단락에만.
  func test_paragraphs_splitsTextPlacesPhotoAndCueOnFirstText() {
    let blocks: [LetterBlock] = [
      .photo(photo("p0")),
      .text("하나\n\n둘"),
      .photo(photo("p1")),
      .text("셋")
    ]

    let paragraphs = LetterContentCodec.paragraphs(blocks: blocks, cue: cue)

    XCTAssertEqual(paragraphs.map(\.order), [0, 1, 2, 3, 4])
    XCTAssertEqual(paragraphs.map(\.text), ["", "하나", "둘", "", "셋"])
    XCTAssertEqual(paragraphs.map { $0.photo?.path }, ["owner/letter/p0.jpg", nil, nil, "owner/letter/p1.jpg", nil])
    XCTAssertEqual(paragraphs[3].id, "p1")
    XCTAssertEqual(paragraphs.map { $0.cue != nil }, [false, true, false, false, false])
  }

  /// 사진만 있는 편지도 큐를 잃지 않도록 맨 앞에 빈 텍스트 단락을 둔다.
  func test_paragraphs_photoOnlyKeepsCueOnLeadingEmptyText() {
    let paragraphs = LetterContentCodec.paragraphs(blocks: [.photo(photo("p0"))], cue: cue)

    XCTAssertEqual(paragraphs.count, 2)
    XCTAssertEqual(paragraphs[0].text, "")
    XCTAssertNotNil(paragraphs[0].cue)
    XCTAssertNil(paragraphs[0].photo)
    XCTAssertEqual(paragraphs[1].photo?.path, "owner/letter/p0.jpg")
    XCTAssertEqual(LetterContentCodec.cue(from: paragraphs)?.ref, cue.ref)
  }

  /// 업로드 전(path 없는) 사진은 저장 형식에 실리지 않는다.
  func test_paragraphs_skipsPendingPhoto() {
    let pending = LetterPhoto(id: "x", path: nil, width: 10, height: 10, pendingJPEG: Data([1]))
    let paragraphs = LetterContentCodec.paragraphs(blocks: [.text("본문"), .photo(pending)], cue: nil)

    XCTAssertEqual(paragraphs.map(\.text), ["본문"])
    XCTAssertTrue(paragraphs.allSatisfy { $0.photo == nil })
  }

  /// 블록 → 단락 → 블록 왕복에서 순서·사진이 보존된다.
  func test_roundTrip_preservesBlocks() throws {
    let blocks: [LetterBlock] = [.text("하나\n\n둘"), .photo(photo("p1")), .text("셋")]

    let encoded = try JSONEncoder().encode(LetterContentCodec.paragraphs(blocks: blocks, cue: cue))
    let decoded = try JSONDecoder().decode([ParagraphDTO].self, from: encoded)

    XCTAssertEqual(LetterContentCodec.blocks(from: decoded), blocks)
    XCTAssertEqual(LetterContentCodec.cue(from: decoded)?.ref, cue.ref)
  }

  /// 저장 JSON에서 텍스트 단락은 photo 키 자체가 없다(구버전 클라이언트·웹 계약 유지).
  func test_paragraphs_textParagraphOmitsPhotoKey() throws {
    let data = try JSONEncoder().encode(LetterContentCodec.paragraphs(blocks: [.text("본문")], cue: nil))
    let json = try XCTUnwrap(String(data: data, encoding: .utf8))

    XCTAssertFalse(json.contains("photo"))
  }

  /// 구 형식(photo 키 없음) 페이로드는 텍스트 블록 하나로 읽힌다.
  func test_blocks_legacyPayloadWithoutPhoto() throws {
    let legacyJSON = Data("""
    [{"id":"1","order":1,"text":"둘째"},{"id":"0","order":0,"text":"첫째","cue":{"sourceType":"hosted","ref":"t"}}]
    """.utf8)
    let paragraphs = try JSONDecoder().decode([ParagraphDTO].self, from: legacyJSON)

    XCTAssertEqual(LetterContentCodec.blocks(from: paragraphs), [.text("첫째\n\n둘째")])
    XCTAssertEqual(LetterContentCodec.cue(from: paragraphs)?.source, .hosted)
  }
}
