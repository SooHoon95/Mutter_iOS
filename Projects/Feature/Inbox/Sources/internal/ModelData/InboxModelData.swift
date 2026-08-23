import Foundation

import Domain

/// 받은함 탭 — 보관한 편지 목록.
@MainActor
@Observable
final class InboxModelData {
  var items: [InboxItem] = []
  var isLoading = false

  private let inboxUsecase: InboxUsecasable

  init(inboxUsecase: InboxUsecasable) {
    self.inboxUsecase = inboxUsecase
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    items = (try? await inboxUsecase.myInbox()) ?? []
  }

  /// 스와이프 삭제 — 낙관적으로 목록에서 먼저 제거하고, 서버 삭제 실패 시 그 항목만 되살린다.
  /// (전체 스냅샷 복원은 연속 삭제 중 다른 항목까지 부활시키는 레이스가 있어 항목 단위로 롤백한다.)
  func delete(_ item: InboxItem) async {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
    let removed = items.remove(at: index)
    do {
      try await inboxUsecase.remove(letterId: item.letterId)
    } catch {
      items.insert(removed, at: min(index, items.count))
    }
  }
}
