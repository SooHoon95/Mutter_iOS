import XCTest

@testable import Domain

/// 편지 사진 저장 흐름(스펙 §5): letterId 확보 → 업로드 → 경로 반영 update → 안 쓰는 객체 정리.
final class LetterUsecaseTests: XCTestCase {
  private final class FakeLetterRepository: LetterRepositorable {
    var created: [LetterDraft] = []
    var updated: [(id: String, draft: LetterDraft)] = []
    var deleted: [String] = []

    func create(_ draft: LetterDraft) async throws -> Letter {
      created.append(draft)
      return Letter(id: "L1", title: draft.title, blocks: draft.blocks.filter { $0.photo?.path != nil || $0.photo == nil }, templateId: draft.templateId)
    }
    func update(id: String, _ draft: LetterDraft) async throws { updated.append((id, draft)) }
    func letter(id: String) async throws -> Letter? { nil }
    func myLetters() async throws -> [Letter] { [] }
    func myLettersWithStatus() async throws -> [LetterWithStatus] { [] }
    func delete(id: String) async throws { deleted.append(id) }
  }

  private struct UploadFailed: Error {}

  private final class FakePhotoRepository: LetterPhotoRepositorable {
    var stored: [String] = []
    var removed: [String] = []
    var deletedAll: [String] = []
    var failUpload = false
    private var counter = 0

    func upload(jpeg: Data, letterId: String) async throws -> String {
      if failUpload { throw UploadFailed() }
      counter += 1
      let path = "u/\(letterId)/\(counter).jpg"
      stored.append(path)
      return path
    }
    func storedPaths(letterId: String) async throws -> [String] { stored }
    func delete(paths: [String]) async throws { removed += paths }
    func deleteAll(letterId: String) async throws { deletedAll.append(letterId) }
    func signedURLs(token: String, password: String?) async throws -> [String: URL] { [:] }
    func signedURLs(letterId: String) async throws -> [String: URL] { [:] }
  }

  private func pending(_ id: String) -> LetterPhoto {
    LetterPhoto(id: id, width: 4, height: 3, pendingJPEG: Data([0xFF]))
  }

  func test_create_withPendingPhotos_createsThenUploadsThenUpdatesWithPaths() async throws {
    let letters = FakeLetterRepository()
    let photos = FakePhotoRepository()
    let usecase = LetterUsecase(repository: letters, photoRepository: photos)
    let draft = LetterDraft(title: "t", blocks: [.text("a"), .photo(pending("p1")), .text("b")], templateId: "x")

    let letter = try await usecase.create(draft)

    XCTAssertEqual(letters.created.count, 1)
    XCTAssertEqual(letters.updated.map(\.id), ["L1"])
    let saved = try XCTUnwrap(letters.updated.first?.draft.blocks.photos.first)
    XCTAssertEqual(saved.id, "p1")
    XCTAssertEqual(saved.path, "u/L1/1.jpg")
    XCTAssertNil(saved.pendingJPEG)
    XCTAssertEqual(letter.blocks.photoPaths, ["u/L1/1.jpg"])
  }

  func test_create_withoutPhotos_skipsUpdate() async throws {
    let letters = FakeLetterRepository()
    let usecase = LetterUsecase(repository: letters, photoRepository: FakePhotoRepository())

    _ = try await usecase.create(LetterDraft(title: "t", body: "본문", templateId: "x"))

    XCTAssertTrue(letters.updated.isEmpty)
  }

  /// 업로드가 실패하면 저장 실패지만, 이미 생긴 행의 id를 알려 중복 생성을 막는다.
  func test_create_uploadFailure_throwsPhotoSaveErrorWithLetterId() async {
    let letters = FakeLetterRepository()
    let photos = FakePhotoRepository()
    photos.failUpload = true
    let usecase = LetterUsecase(repository: letters, photoRepository: photos)

    do {
      _ = try await usecase.create(LetterDraft(title: "t", blocks: [.photo(pending("p1"))], templateId: "x"))
      XCTFail("업로드 실패가 저장 실패로 올라와야 한다")
    } catch let error as LetterPhotoSaveError {
      XCTAssertEqual(error.letterId, "L1")
      XCTAssertTrue(letters.updated.isEmpty)
    } catch {
      XCTFail("예상 밖 에러: \(error)")
    }
  }

  /// 본문이 더 참조하지 않는 객체(지운 사진·지난 실패 업로드)는 update 뒤 지운다.
  func test_update_removesUnreferencedStoredPhotos() async throws {
    let photos = FakePhotoRepository()
    photos.stored = ["u/L1/keep.jpg", "u/L1/old.jpg"]
    let usecase = LetterUsecase(repository: FakeLetterRepository(), photoRepository: photos)
    let kept = LetterPhoto(id: "k", path: "u/L1/keep.jpg", width: 1, height: 1)

    let blocks = try await usecase.update(id: "L1", LetterDraft(title: "t", blocks: [.photo(kept), .photo(pending("n"))], templateId: "x"))

    XCTAssertEqual(blocks.photoPaths, ["u/L1/keep.jpg", "u/L1/1.jpg"])
    XCTAssertEqual(photos.removed, ["u/L1/old.jpg"])
  }

  func test_delete_alsoRemovesPhotoFolder() async throws {
    let photos = FakePhotoRepository()
    let usecase = LetterUsecase(repository: FakeLetterRepository(), photoRepository: photos)

    try await usecase.delete(id: "L1")

    XCTAssertEqual(photos.deletedAll, ["L1"])
  }

  func test_body_joinsOnlyTextBlocks() {
    let letter = Letter(id: "1", title: "t", blocks: [.text("a"), .photo(pending("p")), .text("b")], templateId: "x")

    XCTAssertEqual(letter.body, "a\n\nb")
    XCTAssertEqual(LetterDraft(title: "t", body: "본문", templateId: "x").blocks, [.text("본문")])
  }
}
