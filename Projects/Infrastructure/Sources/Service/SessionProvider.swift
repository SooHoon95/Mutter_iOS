import Foundation

import Supabase

import Domain
import Networking

/// `SessionProvidable` 구현 — 캐시된 세션에서 현재 userId를 동기 조회.
public final class SessionProvider: SessionProvidable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public var currentUserId: String? {
    provider.client.auth.currentUser?.id.uuidString
  }
}
