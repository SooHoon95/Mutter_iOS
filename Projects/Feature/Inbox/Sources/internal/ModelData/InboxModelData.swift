import Foundation

import AppFoundation
import Domain
import UIComponent

/// 받은함 탭 — 보관한 편지 목록 + 편집 모드(여러 통 선택 삭제).
/// 삭제는 서버 `inbox` 뷰가 30일 보관(받은 편지 삭제함)으로 바꾸므로 즉시 요청하고, 되돌리기는 restore RPC로 한다.
@MainActor
@Observable
final class InboxModelData {
  var items: [InboxItem] = []
  var isLoading = false
  var errorMessage: String?

  /// 편집 모드 — 카드 탭이 열기 대신 선택 토글이 되고, 스와이프·당겨서 새로고침을 끈다.
  var isEditing = false
  /// 선택된 항목(InboxItem.id).
  var selectedIds: Set<String> = []

  /// 방금 삭제함으로 옮긴 편지들 — "되돌리기" 토스트가 떠 있는 동안만 비어 있지 않다.
  var undoableLetterIds: [String] = []

  /// letterId → 접근 상태(영구·n일 남음·닫힘). 조회 실패(배포 전 포함)면 비어 있어 지금처럼 보인다.
  private(set) var accessStates: [String: LetterAccessState] = [:]
  /// 편지권 UI 노출 판단. nil이면 "영구" 표시를 숨긴다.
  private(set) var entitlements: Entitlements?

  /// 되돌리기 창(세 플랫폼 공통 5초).
  private static let undoWindow: Duration = .seconds(5)
  private let inboxUsecase: InboxUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable
  @ObservationIgnored private var undoToastTask: Task<Void, Never>?

  init(inboxUsecase: InboxUsecasable, letterAccessUsecase: LetterAccessUsecasable, ticketUsecase: TicketUsecasable) {
    self.inboxUsecase = inboxUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
  }

  /// 목록 행의 접근 상태 배지.
  func accessBadge(for item: InboxItem) -> LetterAccessBadgeType? {
    accessStates[item.letterId]?.badge(showsPermanent: entitlements?.showsTicketUI ?? false)
  }

  var isAllSelected: Bool { !items.isEmpty && selectedIds.count == items.count }

  /// 토스트 문구 — 한 통 / 여러 통.
  var undoToastMessage: String {
    undoableLetterIds.count > 1 ? L10n.inboxMovedToTrashMany(undoableLetterIds.count) : L10n.inboxMovedToTrash
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    items = (try? await inboxUsecase.myInbox()) ?? []
    // 사라진 항목의 선택은 남기지 않는다(삭제 버튼 개수가 실제와 어긋나지 않게).
    selectedIds.formIntersection(items.map(\.id))
    // 상태·권한은 표시용 부가 정보 — 실패하면 조용히 비워 두고 목록은 그대로 보인다.
    async let statesTask = letterAccessUsecase.accessStates(letterIds: items.map(\.letterId))
    async let entitlementsTask = ticketUsecase.entitlements()
    accessStates = (try? await statesTask) ?? [:]
    entitlements = try? await entitlementsTask
  }

  // MARK: - 편집 모드

  func toggleEditing() {
    isEditing.toggle()
    selectedIds = []
  }

  func toggleSelection(_ item: InboxItem) {
    if selectedIds.contains(item.id) {
      selectedIds.remove(item.id)
    } else {
      selectedIds.insert(item.id)
    }
  }

  /// "전체 선택" / 모두 선택돼 있으면 "선택 해제".
  func toggleSelectAll() {
    selectedIds = isAllSelected ? [] : Set(items.map(\.id))
  }

  func deleteSelected() async {
    await delete(items.filter { selectedIds.contains($0.id) })
  }

  // MARK: - 삭제·되돌리기

  /// 삭제(편집 모드·스와이프 공통) — 목록에서 먼저 빼고 서버에 삭제한 뒤 편집 모드를 끝내고 되돌리기 토스트.
  /// 실패하면 뺀 항목만 원래 자리로 되살린다(전체 스냅샷 복원은 연속 삭제 중 다른 항목까지 부활시킨다).
  func delete(_ targets: [InboxItem]) async {
    guard !targets.isEmpty else { return }
    errorMessage = nil
    let targetIds = Set(targets.map(\.id))
    // 원래 순서대로 (자리, 항목)을 기억해 두고 뺀다.
    let removed = items.enumerated().filter { targetIds.contains($0.element.id) }
    items.removeAll { targetIds.contains($0.id) }
    let letterIds = removed.map(\.element.letterId)
    do {
      try await inboxUsecase.remove(letterIds: letterIds)
      isEditing = false
      selectedIds = []
      showUndoToast(for: letterIds)
    } catch {
      for (index, item) in removed where !items.contains(where: { $0.id == item.id }) {
        items.insert(item, at: min(index, items.count))
      }
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorDelete
    }
  }

  /// 토스트의 "되돌리기" — 삭제함에서 되살린 뒤 목록을 새로 받는다.
  func undoDelete() async {
    let letterIds = undoableLetterIds
    guard !letterIds.isEmpty else { return }
    hideUndoToast()
    errorMessage = nil
    do {
      try await inboxUsecase.restore(letterIds: letterIds)
      await load()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorRestore
    }
  }

  // MARK: - Private

  private func showUndoToast(for letterIds: [String]) {
    undoToastTask?.cancel()
    undoableLetterIds = letterIds
    undoToastTask = Task { [weak self] in
      try? await Task.sleep(for: Self.undoWindow)
      guard !Task.isCancelled else { return }
      self?.undoableLetterIds = []
    }
  }

  private func hideUndoToast() {
    undoToastTask?.cancel()
    undoToastTask = nil
    undoableLetterIds = []
  }
}
