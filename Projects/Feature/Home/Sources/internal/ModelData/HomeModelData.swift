import Foundation

import AppFoundation
import Domain

/// 홈(우체통) — 내가 보낸/쓴 편지 + 읽음 상태.
@MainActor
@Observable
final class HomeModelData {
  struct LetterRow: Identifiable {
    let letter: Letter
    let openSummary: LetterOpenSummary?
    var id: String { letter.id }
    var isOpened: Bool { (openSummary?.openCount ?? 0) > 0 }
  }

  var rows: [LetterRow] = []
  var isLoading = false
  var errorMessage: String?

  private let letterUsecase: LetterUsecasable
  private let receiptUsecase: ReceiptUsecasable

  init(letterUsecase: LetterUsecasable, receiptUsecase: ReceiptUsecasable) {
    self.letterUsecase = letterUsecase
    self.receiptUsecase = receiptUsecase
  }

  var sentCount: Int { rows.count }
  var openedCount: Int { rows.filter(\.isOpened).count }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    async let lettersTask = letterUsecase.myLetters()
    async let opensTask = receiptUsecase.myLetterOpens()
    let letters = (try? await lettersTask) ?? []
    let opens = (try? await opensTask) ?? []
    let openMap = Dictionary(opens.map { ($0.letterId, $0) }, uniquingKeysWith: { first, _ in first })
    rows = letters.map { LetterRow(letter: $0, openSummary: openMap[$0.id]) }
  }

  /// 편지 삭제(임시저장 포함). 성공 시 목록에서 즉시 제거.
  func delete(_ letterId: String) async {
    errorMessage = nil
    do {
      try await letterUsecase.delete(id: letterId)
      rows.removeAll { $0.letter.id == letterId }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "삭제하지 못했어요."
    }
  }
}
