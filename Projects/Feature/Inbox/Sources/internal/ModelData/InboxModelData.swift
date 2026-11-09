import Foundation

import Domain

/// 받은함 탭 — 보관한 편지 목록.
@MainActor
@Observable
final class InboxModelData {
  /// 지연 삭제 대기 중인 항목과 원래 자리.
  struct PendingRemoval {
    let item: InboxItem
    let index: Int
  }

  var items: [InboxItem] = []
  var isLoading = false
  /// "보관함에서 뺐어요" 토스트가 떠 있는 동안의 대기 항목. nil이면 토스트 없음.
  private(set) var pendingRemoval: PendingRemoval?

  /// 되돌리기 창(세 플랫폼 공통 5초).
  private static let undoWindow: Duration = .seconds(5)
  private let inboxUsecase: InboxUsecasable
  @ObservationIgnored private var commitTask: Task<Void, Never>?

  init(inboxUsecase: InboxUsecasable) {
    self.inboxUsecase = inboxUsecase
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    let loaded = (try? await inboxUsecase.myInbox()) ?? []
    // 되돌리기 창 안의 항목은 아직 서버에 남아 있으므로, 새로고침해도 다시 나타나지 않게 거른다.
    items = loaded.filter { $0.id != pendingRemoval?.item.id }
  }

  /// 스와이프 삭제 — 지연 삭제. 목록에서 바로 숨기고 되돌리기 창(5초)이 닫힐 때 실제로 지운다.
  /// 받은함은 서버 보관(삭제함)이 없어 지운 뒤 다시 넣어야 하는데, 재-insert는 `on_inbox_insert` 푸시 트리거를
  /// 또 울리므로 "요청을 늦추는" 방식으로 되돌리기를 만든다(세 플랫폼 공통).
  func delete(_ item: InboxItem) {
    // 앞선 대기 항목은 새 삭제가 들어오는 순간 확정한다 — 토스트는 하나라 되돌리기 대상도 하나만 둔다.
    if let previous = takePendingRemoval() {
      Task { await send(previous) }
    }
    guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
    let removed = items.remove(at: index)
    pendingRemoval = PendingRemoval(item: removed, index: index)
    commitTask = Task { [weak self] in
      try? await Task.sleep(for: Self.undoWindow)
      guard !Task.isCancelled, let self else { return }
      // 자기 자신을 취소하면 이어지는 삭제 요청까지 취소되므로, 확정 전에 핸들만 비운다.
      self.commitTask = nil
      await self.commitPendingRemoval()
    }
  }

  /// 토스트의 "되돌리기" — 아직 요청을 보내지 않았으므로 원래 자리에 다시 보여주기만 한다.
  func undoRemoval() {
    guard let pending = takePendingRemoval() else { return }
    items.insert(pending.item, at: min(pending.index, items.count))
  }

  /// 대기 중인 삭제를 실제로 보낸다(시간 만료·화면 이탈·앱 백그라운드).
  func commitPendingRemoval() async {
    guard let pending = takePendingRemoval() else { return }
    await send(pending)
  }

  // MARK: - Private

  /// 대기 항목을 꺼내고 타이머를 멈춘다(토스트도 함께 닫힌다).
  private func takePendingRemoval() -> PendingRemoval? {
    guard let pending = pendingRemoval else { return nil }
    commitTask?.cancel()
    commitTask = nil
    pendingRemoval = nil
    return pending
  }

  /// 서버 삭제. 실패하면 그 항목만 되살린다(전체 스냅샷 복원은 연속 삭제 중 다른 항목까지 부활시킨다).
  private func send(_ pending: PendingRemoval) async {
    do {
      try await inboxUsecase.remove(letterId: pending.item.letterId)
    } catch {
      guard !items.contains(where: { $0.id == pending.item.id }) else { return }
      items.insert(pending.item, at: min(pending.index, items.count))
    }
  }
}
