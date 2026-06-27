import Foundation

import Domain

/// 스레드 탭 — 주고받은 상대 목록 + 선택 상대와의 편지.
@MainActor
@Observable
final class ThreadsModelData {
  var counterparts: [Counterpart] = []
  var selectedCounterpart: Counterpart?
  var thread: [ThreadLetter] = []
  var isLoading = false

  private let threadUsecase: ThreadUsecasable

  init(threadUsecase: ThreadUsecasable) {
    self.threadUsecase = threadUsecase
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    counterparts = (try? await threadUsecase.counterparts()) ?? []
  }

  func openThread(_ counterpart: Counterpart) async {
    selectedCounterpart = counterpart
    thread = (try? await threadUsecase.thread(counterpartId: counterpart.userId)) ?? []
  }

  func closeThread() {
    selectedCounterpart = nil
    thread = []
  }
}
