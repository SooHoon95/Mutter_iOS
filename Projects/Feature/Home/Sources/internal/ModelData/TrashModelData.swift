import Foundation

import AppFoundation
import Domain
import UIComponent

/// 삭제함 — 30일 보관 중인 내 편지. 복구하거나 완전히 삭제한다.
@MainActor
@Observable
final class TrashModelData {
  var items: [DeletedLetter] = []
  var isLoading = false
  var errorMessage: String?
  /// "편지를 되살렸어요" 토스트 표시 여부.
  var showsRestoredToast = false

  private static let toastDuration: Duration = .seconds(2)
  private let letterUsecase: LetterUsecasable
  @ObservationIgnored private var toastTask: Task<Void, Never>?

  init(letterUsecase: LetterUsecasable) {
    self.letterUsecase = letterUsecase
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      items = try await letterUsecase.deletedLetters()
      errorMessage = nil
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.trashErrorLoad
    }
  }

  /// 복구 — 성공하면 행을 빼고 토스트. 홈 목록은 돌아갈 때 다시 받아 오므로 여기서 알릴 필요가 없다.
  func restore(_ item: DeletedLetter) async {
    errorMessage = nil
    do {
      try await letterUsecase.restore(id: item.id)
      items.removeAll { $0.id == item.id }
      showRestoredToast()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorRestore
    }
  }

  /// 완전히 삭제 — 되돌릴 수 없으므로 서버가 받아들인 뒤에만 행을 뺀다(낙관적 제거 없음).
  func purge(_ item: DeletedLetter) async {
    errorMessage = nil
    do {
      try await letterUsecase.purge(id: item.id)
      items.removeAll { $0.id == item.id }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorDelete
    }
  }

  // MARK: - Private

  private func showRestoredToast() {
    toastTask?.cancel()
    showsRestoredToast = true
    toastTask = Task { [weak self] in
      try? await Task.sleep(for: Self.toastDuration)
      guard !Task.isCancelled else { return }
      self?.showsRestoredToast = false
    }
  }
}
