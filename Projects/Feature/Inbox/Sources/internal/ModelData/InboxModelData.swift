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
}
