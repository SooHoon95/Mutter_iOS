import Foundation

import AppFoundation
import Domain
import UIComponent

/// 홈(우체통) — 내가 보낸/쓴 편지 + 읽음 상태.
@MainActor
@Observable
final class HomeModelData {
  struct LetterRow: Identifiable {
    let letter: Letter
    let openSummary: LetterOpenSummary?
    /// 전달됨(보낸 편지) 여부 — false면 임시저장(작성 중).
    let isSent: Bool
    var id: String { letter.id }
    var isOpened: Bool { (openSummary?.openCount ?? 0) > 0 }
  }

  var rows: [LetterRow] = []
  var isLoading = false
  var errorMessage: String?
  /// 방금 삭제함으로 옮긴 편지 — "되돌리기" 토스트가 떠 있는 동안만 non-nil.
  var undoableLetterId: String?

  /// 되돌리기 창(세 플랫폼 공통 5초).
  private static let undoWindow: Duration = .seconds(5)
  @ObservationIgnored private var undoToastTask: Task<Void, Never>?

  private let letterUsecase: LetterUsecasable
  private let receiptUsecase: ReceiptUsecasable

  init(letterUsecase: LetterUsecasable, receiptUsecase: ReceiptUsecasable) {
    self.letterUsecase = letterUsecase
    self.receiptUsecase = receiptUsecase
  }

  /// 보낸 편지(전달됨) — 통계·"보낸 편지" 탭.
  var sentRows: [LetterRow] { rows.filter(\.isSent) }
  /// 임시저장(미전달) — "임시저장" 탭. 탭하면 이어쓰기.
  var draftRows: [LetterRow] { rows.filter { !$0.isSent } }
  var sentCount: Int { sentRows.count }
  var openedCount: Int { sentRows.filter(\.isOpened).count }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    async let lettersTask = letterUsecase.myLettersWithStatus()
    async let opensTask = receiptUsecase.myLetterOpens()
    let letters = (try? await lettersTask) ?? []
    let opens = (try? await opensTask) ?? []
    let openMap = Dictionary(opens.map { ($0.letterId, $0) }, uniquingKeysWith: { first, _ in first })
    rows = letters.map { LetterRow(letter: $0.letter, openSummary: openMap[$0.letter.id], isSent: $0.isSent) }
  }

  /// 편지 삭제(임시저장 포함) — 서버에서 30일 보관(삭제함)으로 바뀐다.
  /// 목록에서 먼저 빼고, 서버가 받아들이면 "되돌리기" 토스트를 띄운다. 실패하면 그 항목만 되살린다
  /// (전체 스냅샷 복원은 연속 삭제 중 다른 항목까지 부활시키므로 항목 단위로 롤백한다).
  /// 토스트를 요청 성공 뒤에 띄우는 이유: 삭제가 끝나기 전 "되돌리기"가 눌리면 복구가 삭제보다 먼저 도착할 수 있다.
  func delete(_ letterId: String) async {
    errorMessage = nil
    guard let index = rows.firstIndex(where: { $0.id == letterId }) else { return }
    let removed = rows.remove(at: index)
    do {
      try await letterUsecase.delete(id: letterId)
      showUndoToast(for: letterId)
    } catch {
      rows.insert(removed, at: min(index, rows.count))
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorDelete
    }
  }

  /// 토스트의 "되돌리기" — 삭제함에서 되살린 뒤 목록을 새로 받는다(발송 여부·열람 요약까지 서버 기준으로).
  func undoDelete() async {
    guard let letterId = undoableLetterId else { return }
    hideUndoToast()
    errorMessage = nil
    do {
      try await letterUsecase.restore(id: letterId)
      await load()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorRestore
    }
  }

  // MARK: - Private

  private func showUndoToast(for letterId: String) {
    undoToastTask?.cancel()
    undoableLetterId = letterId
    undoToastTask = Task { [weak self] in
      try? await Task.sleep(for: Self.undoWindow)
      guard !Task.isCancelled else { return }
      self?.undoableLetterId = nil
    }
  }

  private func hideUndoToast() {
    undoToastTask?.cancel()
    undoToastTask = nil
    undoableLetterId = nil
  }
}
