import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `AppClientRepositorable` 구현 — report_app_client RPC(서버가 auth.uid로 소유자 강제).
public final class AppClientRepository: AppClientRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func report(platform: String, appVersion: String, build: String?) async throws {
    do {
      try await provider.client
        .rpc(
          "report_app_client",
          params: ReportAppClientParams(platform: platform, appVersion: appVersion, build: build)
        )
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
