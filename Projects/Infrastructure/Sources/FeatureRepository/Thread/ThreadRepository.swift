import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `ThreadRepositorable` 구현 — 상대별 주고받음/보낸편지 조회(RPC).
public final class ThreadRepository: ThreadRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func counterparts() async throws -> [Counterpart] {
    do {
      let rows: [CounterpartRow] = try await provider.client
        .rpc("get_counterparts")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func thread(counterpartId: String) async throws -> [ThreadLetter] {
    do {
      let rows: [ThreadLetterRow] = try await provider.client
        .rpc("get_thread", params: ThreadParams(counterpart: counterpartId))
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func sentWithRecipients() async throws -> [SentLetterSummary] {
    do {
      let rows: [SentWithRecipientRow] = try await provider.client
        .rpc("get_my_sent_with_recipients")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
