import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `PushTokenRepositorable` 구현 — upsert_push_token RPC(서버가 auth.uid로 소유자 강제).
public final class PushTokenRepository: PushTokenRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func upsert(token: String, platform: String, deviceId: String?) async throws {
    do {
      try await provider.client
        .rpc(
          "upsert_push_token",
          params: UpsertPushTokenParams(token: token, platform: platform, deviceId: deviceId)
        )
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
