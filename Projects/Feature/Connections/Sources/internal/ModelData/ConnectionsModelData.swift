import Foundation

import AppFoundation
import Domain

/// 연결 탭 — N:N 연결 목록, 초대 링크 생성, 특정 연결 해제.
@MainActor
@Observable
final class ConnectionsModelData {
  var connections: [Connection] = []
  var inviteToken: String?
  var isLoading = false
  var errorMessage: String?

  private let connectionUsecase: ConnectionUsecasable

  init(connectionUsecase: ConnectionUsecasable) {
    self.connectionUsecase = connectionUsecase
  }

  var hasConnections: Bool { !connections.isEmpty }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    connections = (try? await connectionUsecase.myConnections()) ?? []
  }

  /// 초대 토큰 생성 → 공유 링크는 `/connect/<token>`.
  func createInvite() async {
    await run {
      inviteToken = try await connectionUsecase.createInvite()
    }
  }

  /// 초대 링크 취소 — 상대가 아직 수락하지 않은 경우 무효화 (EC-2.8).
  func revokeInvite() async {
    guard let token = inviteToken else { return }
    await run {
      try await connectionUsecase.revokeInvite(token: token)
      inviteToken = nil
    }
  }

  /// 특정 상대와의 연결 해제(N:N).
  func disconnect(otherUserId: String) async {
    await run {
      try await connectionUsecase.disconnect(otherUserId: otherUserId)
      connections.removeAll { $0.userId == otherUserId }
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
