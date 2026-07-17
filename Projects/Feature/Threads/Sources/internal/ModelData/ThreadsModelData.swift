import Foundation

import Domain
import UIComponent

/// 스레드 탭 — 주고받은 상대 목록 + 선택 상대와의 편지.
@MainActor
@Observable
final class ThreadsModelData {
  var counterparts: [Counterpart] = []
  var selectedCounterpart: Counterpart?
  var thread: [ThreadLetter] = []
  var isLoading = false
  /// 스레드 시트 로드 중 — 빈 시트 대신 로딩 스피너를 보여주기 위함.
  var isThreadLoading = false
  /// 스레드 로드 실패 메시지 — 에러를 삼키지 않고 시트에 드러낸다.
  var threadError: String?

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
    thread = []
    threadError = nil
    isThreadLoading = true
    defer { isThreadLoading = false }
    do {
      thread = try await threadUsecase.thread(counterpartId: counterpart.userId)
    } catch {
      // 실패를 삼키지 않고 시트에 에러 상태로 드러낸다(빈 시트 방지).
      threadError = L10n.threadsSheetLoadError
    }
  }

  func closeThread() {
    selectedCounterpart = nil
    thread = []
    threadError = nil
  }
}
