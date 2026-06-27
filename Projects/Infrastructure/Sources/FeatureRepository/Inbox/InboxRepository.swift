import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `InboxRepositorable` 구현 — 받은함 저장/조회(RPC).
public final class InboxRepository: InboxRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func save(token: String) async throws {
    do {
      try await provider.client
        .rpc("save_to_inbox", params: TokenParam(token: token))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func myInbox() async throws -> [InboxItem] {
    do {
      let rows: [InboxRow] = try await provider.client
        .rpc("get_my_inbox")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
