import XCTest

@testable import Home
import Domain

/// 최소 페이크 — MU-3에서 추가한 myLettersWithStatus만 의미 있고 나머지는 미사용.
private struct FakeLetterUsecase: LetterUsecasable {
  var lettersWithStatus: [LetterWithStatus]
  func create(_ draft: LetterDraft) async throws -> Letter { fatalError("unused in test") }
  func update(id: String, _ draft: LetterDraft) async throws -> [LetterBlock] { draft.blocks }
  func letter(id: String) async throws -> Letter? { nil }
  func myLetters() async throws -> [Letter] { lettersWithStatus.map(\.letter) }
  func myLettersWithStatus() async throws -> [LetterWithStatus] { lettersWithStatus }
  func delete(id: String) async throws {}
  func deletedLetters() async throws -> [DeletedLetter] { [] }
  func restore(id: String) async throws {}
  func purge(id: String) async throws {}
  func photoURLs(token: String, password: String?) async throws -> [String: URL] { [:] }
  func photoURLs(letterId: String) async throws -> [String: URL] { [:] }
}

private struct FakeReceiptUsecase: ReceiptUsecasable {
  var opens: [LetterOpenSummary] = []
  func recordOpen(token: String) async throws {}
  func myLetterOpens() async throws -> [LetterOpenSummary] { opens }
}

/// 영구 편지권 RPC가 없는 서버(배포 전)처럼 항상 실패 — 목록은 기존대로 보여야 한다.
private struct FakeLetterAccessUsecase: LetterAccessUsecasable {
  func cover(token: String) async throws -> LetterCover { throw URLError(.badServerResponse) }
  func accessStates(letterIds: [String]) async throws -> [String: LetterAccessState] { throw URLError(.badServerResponse) }
  func readers(letterId: String) async throws -> [LetterReader] { throw URLError(.badServerResponse) }
  func duplicate(letterId: String) async throws -> String { throw URLError(.badServerResponse) }
}

private struct FakeTicketUsecase: TicketUsecasable {
  func entitlements() async throws -> Entitlements { throw URLError(.badServerResponse) }
  func history() async throws -> [TicketHistoryItem] { throw URLError(.badServerResponse) }
  func makePermanent(letterId: String) async throws { throw URLError(.badServerResponse) }
  func keepReceived(token: String, password: String?) async throws { throw URLError(.badServerResponse) }
}

final class HomeTests: XCTestCase {
  private func letter(_ id: String) -> Letter {
    Letter(id: id, title: "t\(id)", body: "b", templateId: "classic-serif")
  }

  /// AC①② — 임시저장은 보낸 편지 목록·통계에 섞이지 않는다.
  @MainActor
  func test_load_splitsSentAndDraft_andStatsCountSentOnly() async {
    let rows = [
      LetterWithStatus(letter: letter("1"), isSent: true),
      LetterWithStatus(letter: letter("2"), isSent: false),   // 임시저장
      LetterWithStatus(letter: letter("3"), isSent: true),
    ]
    let opens = [LetterOpenSummary(letterId: "1", openCount: 2, lastOpenedAt: Date())]
    let model = HomeModelData(
      letterUsecase: FakeLetterUsecase(lettersWithStatus: rows),
      receiptUsecase: FakeReceiptUsecase(opens: opens),
      letterAccessUsecase: FakeLetterAccessUsecase(),
      ticketUsecase: FakeTicketUsecase()
    )

    await model.load()

    XCTAssertEqual(model.sentRows.map(\.letter.id).sorted(), ["1", "3"])
    XCTAssertEqual(model.draftRows.map(\.letter.id), ["2"])
    XCTAssertEqual(model.sentCount, 2)     // 임시저장(2)은 통계에서 제외
    XCTAssertEqual(model.openedCount, 1)   // 보낸 편지 중 열린 것만(1)
  }

  /// 임시저장에 우연히 open 기록이 있어도 통계는 보낸 편지만 센다.
  @MainActor
  func test_load_draftNotCountedInStats() async {
    let rows = [LetterWithStatus(letter: letter("d"), isSent: false)]
    let opens = [LetterOpenSummary(letterId: "d", openCount: 5, lastOpenedAt: Date())]
    let model = HomeModelData(
      letterUsecase: FakeLetterUsecase(lettersWithStatus: rows),
      receiptUsecase: FakeReceiptUsecase(opens: opens),
      letterAccessUsecase: FakeLetterAccessUsecase(),
      ticketUsecase: FakeTicketUsecase()
    )

    await model.load()

    XCTAssertEqual(model.sentCount, 0)
    XCTAssertEqual(model.openedCount, 0)
    XCTAssertEqual(model.draftRows.count, 1)
  }
}
