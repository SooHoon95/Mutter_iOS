import XCTest

@testable import Home
import Domain

/// 최소 페이크 — MU-3에서 추가한 myLettersWithStatus만 의미 있고 나머지는 미사용.
private struct FakeLetterUsecase: LetterUsecasable {
  var lettersWithStatus: [LetterWithStatus]
  func create(_ draft: LetterDraft) async throws -> Letter { fatalError("unused in test") }
  func update(id: String, _ draft: LetterDraft) async throws {}
  func letter(id: String) async throws -> Letter? { nil }
  func myLetters() async throws -> [Letter] { lettersWithStatus.map(\.letter) }
  func myLettersWithStatus() async throws -> [LetterWithStatus] { lettersWithStatus }
  func delete(id: String) async throws {}
}

private struct FakeReceiptUsecase: ReceiptUsecasable {
  var opens: [LetterOpenSummary] = []
  func recordOpen(token: String) async throws {}
  func myLetterOpens() async throws -> [LetterOpenSummary] { opens }
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
      receiptUsecase: FakeReceiptUsecase(opens: opens)
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
      receiptUsecase: FakeReceiptUsecase(opens: opens)
    )

    await model.load()

    XCTAssertEqual(model.sentCount, 0)
    XCTAssertEqual(model.openedCount, 0)
    XCTAssertEqual(model.draftRows.count, 1)
  }
}
