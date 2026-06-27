import Foundation

import AppFoundation
import Domain

/// 연결 탭 — 독점 1:1 연결 상태, 초대 링크 생성, 연결 해제.
@MainActor
@Observable
final class ConnectionsModelData {
  var connection: Connection?
  var inviteToken: String?
  var isLoading = false
  var errorMessage: String?

  private let connectionUsecase: ConnectionUsecasable

  init(connectionUsecase: ConnectionUsecasable) {
    self.connectionUsecase = connectionUsecase
  }

  var isConnected: Bool { connection != nil }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    connection = (try? await connectionUsecase.myConnections())?.first
  }

  /// 초대 토큰 생성 → 공유 링크는 `/connect/<token>`.
  func createInvite() async {
    await run {
      inviteToken = try await connectionUsecase.createInvite()
    }
  }

  func disconnect() async {
    await run {
      try await connectionUsecase.disconnect()
      connection = nil
      inviteToken = nil
    }
  }

  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? "잠시 후 다시 시도해 주세요."
    }
  }
}
