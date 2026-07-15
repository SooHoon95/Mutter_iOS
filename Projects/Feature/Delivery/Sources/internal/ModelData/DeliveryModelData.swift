import Foundation

import AppFoundation
import Domain
import UIComponent

/// 전달 링크 발급/관리 — 암호 기본 ON, 예약공개, revoke.
@MainActor
@Observable
final class DeliveryModelData {
  var links: [DeliveryLink] = []
  /// 암호 기본 ON(기본값이 프라이버시).
  var usePassword = true
  var password = ""
  var useReveal = false
  var revealAt = Date().addingTimeInterval(3600)
  var isLoading = false
  var errorMessage: String?
  var lastIssuedToken: String?

  private let letterId: String
  private let deliveryUsecase: DeliveryUsecasable

  init(letterId: String, deliveryUsecase: DeliveryUsecasable) {
    self.letterId = letterId
    self.deliveryUsecase = deliveryUsecase
  }

  var canIssue: Bool {
    usePassword ? !password.isEmpty : true
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    links = (try? await deliveryUsecase.links(letterId: letterId)) ?? []
  }

  func issue() async {
    await run {
      let link = try await deliveryUsecase.issue(
        letterId: letterId,
        password: usePassword ? password : nil,
        revealAt: useReveal ? revealAt : nil
      )
      lastIssuedToken = link.token
      password = ""
      await load()
    }
  }

  func revoke(_ token: String) async {
    await run {
      try await deliveryUsecase.revoke(token: token)
      await load()
    }
  }

  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }
}
