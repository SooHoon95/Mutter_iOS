import Foundation

import AppFoundation
import Domain
import UIComponent

/// 프로필 탭 상태/로직 — 닉네임 수정, 로그아웃, 계정 삭제.
@MainActor
@Observable
final class ProfileModelData {
  var nickname = ""
  var isLoading = false
  var errorMessage: String?
  var savedToast = false
  /// 권한·편지권 잔액. nil이면(조회 실패·배포 전) 편지권 항목을 숨긴다.
  private(set) var entitlements: Entitlements?

  private let profileUsecase: ProfileUsecasable
  private let authUsecase: AuthUsecasable
  private let ticketUsecase: TicketUsecasable
  private let onSignedOut: () -> Void

  init(
    profileUsecase: ProfileUsecasable,
    authUsecase: AuthUsecasable,
    ticketUsecase: TicketUsecasable,
    onSignedOut: @escaping () -> Void
  ) {
    self.profileUsecase = profileUsecase
    self.authUsecase = authUsecase
    self.ticketUsecase = ticketUsecase
    self.onSignedOut = onSignedOut
  }

  /// 프로필의 편지권 항목 — 편지권 UI가 켜진 계정만.
  var showsTickets: Bool { entitlements?.showsTicketUI ?? false }
  var tickets: Int { entitlements?.tickets ?? 0 }

  /// 계정 삭제 확인 문구 — 편지권이 남아 있으면 사라진다는 경고를 덧붙인다.
  var deleteAccountDetail: String {
    guard tickets > 0 else { return L10n.profileDeleteDetail }
    return "\(L10n.ticketDeleteAccountWarning(tickets))\n\(L10n.profileDeleteDetail)"
  }

  func load() async {
    async let profileTask = profileUsecase.myProfile()
    async let entitlementsTask = ticketUsecase.entitlements()
    let profile = try? await profileTask
    nickname = profile?.nickname ?? ""
    entitlements = try? await entitlementsTask
  }

  func saveNickname() async {
    await run {
      try await profileUsecase.updateNickname(nickname)
      savedToast = true
    }
  }

  func signOut() async {
    await run {
      try await authUsecase.signOut()
      onSignedOut()
    }
  }

  func deleteAccount() async {
    await run {
      try await profileUsecase.deleteAccount()
      try? await authUsecase.signOut()
      onSignedOut()
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
