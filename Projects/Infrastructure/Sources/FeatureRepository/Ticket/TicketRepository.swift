import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `TicketRepositorable` 구현 — 권한·잔액·내역 조회와 편지권 사용(RPC). 차감·환급은 서버가 강제한다.
public final class TicketRepository: TicketRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func entitlements() async throws -> Entitlements {
    do {
      let dto: EntitlementsDTO = try await provider.client
        .rpc("get_my_entitlements")
        .execute()
        .value
      return dto.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func history() async throws -> [TicketHistoryItem] {
    do {
      let rows: [TicketHistoryRow] = try await provider.client
        .rpc("get_my_ticket_history")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func makePermanent(letterId: String) async throws {
    do {
      try await provider.client
        .rpc("make_letter_permanent", params: LetterIdParams(letterId: letterId))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func keepReceived(token: String, password: String?) async throws {
    do {
      // p_password는 암호가 없어도 null로 명시해 보낸다(생략하면 PostgREST가 함수를 못 찾는다).
      try await provider.client
        .rpc("keep_received_letter", params: OpenLinkParams(token: token, password: password))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
