import Foundation

import AppFoundation
import Domain
import UIComponent

/// 권리침해 신고(테이크다운) 폼 상태/로직. 익명 허용 — 법적 의무로 항상 접근 가능.
@MainActor
@Observable
final class TakedownModelData {
  var claimant = ""
  var contact = ""
  var reason = ""
  var trackRef = ""
  var isLoading = false
  var errorMessage: String?
  var submitted = false

  private let takedownUsecase: TakedownUsecasable

  init(takedownUsecase: TakedownUsecasable) {
    self.takedownUsecase = takedownUsecase
  }

  var isValid: Bool {
    !claimant.trimmingCharacters(in: .whitespaces).isEmpty
      && !contact.trimmingCharacters(in: .whitespaces).isEmpty
      && !reason.trimmingCharacters(in: .whitespaces).isEmpty
  }

  func submit() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await takedownUsecase.report(
        letterId: nil,
        trackRef: trackRef.isEmpty ? nil : trackRef,
        claimant: claimant,
        contact: contact,
        reason: reason
      )
      submitted = true
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorTakedown
    }
  }
}
