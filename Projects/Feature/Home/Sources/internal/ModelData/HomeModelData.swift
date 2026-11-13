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
  /// letterId → 접근 상태. 조회 실패(배포 전 포함)면 비어 있어 지금처럼 보인다.
  private(set) var accessStates: [String: LetterAccessState] = [:]
  /// 편지권 UI 노출 판단. nil이면 "영구" 표시를 숨긴다.
  private(set) var entitlements: Entitlements?

  /// 되돌리기 창(세 플랫폼 공통 5초).
  private static let undoWindow: Duration = .seconds(5)
  @ObservationIgnored private var undoToastTask: Task<Void, Never>?

  private let letterUsecase: LetterUsecasable
  private let receiptUsecase: ReceiptUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable

  init(
    letterUsecase: LetterUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable
  ) {
    self.letterUsecase = letterUsecase
    self.receiptUsecase = receiptUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
  }

  /// 받은 사람이 편지권으로 간직한 편지 — 지우기 전에 영구가 풀린다고 한 번 묻는다.
  func isKeptByRecipient(_ letterId: String) -> Bool {
    accessStates[letterId]?.keptByRecipient ?? false
  }

  /// 보낸 편지 행의 접근 상태 배지(임시저장은 없음).
  func accessBadge(for row: LetterRow) -> LetterAccessBadgeType? {
    guard row.isSent else { return nil }
    return accessStates[row.id]?.badge(showsPermanent: entitlements?.showsTicketUI ?? false)
  }

  /// 보낸 편지 행의 간직 요청 수(0이면 표시하지 않는다).
  func keepRequestCount(for row: LetterRow) -> Int {
    guard row.isSent else { return 0 }
    return accessStates[row.id]?.keepRequestCount ?? 0
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
    // 상태·권한은 표시용 부가 정보 — 실패하면 조용히 비워 두고 목록은 그대로 보인다.
    async let statesTask = letterAccessUsecase.accessStates(letterIds: sentRows.map(\.id))
    async let entitlementsTask = ticketUsecase.entitlements()
    accessStates = (try? await statesTask) ?? [:]
    entitlements = try? await entitlementsTask
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
