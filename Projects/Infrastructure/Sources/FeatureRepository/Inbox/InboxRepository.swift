import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `InboxRepositorable` 구현 — 받은함 저장/조회(RPC), 삭제(inbox 뷰), 받은 편지 삭제함(RPC).
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

  /// 서버 `inbox` 뷰의 INSTEAD OF DELETE 트리거가 실제 삭제 대신 30일 보관으로 바꾼다.
  /// 한 통이면 `eq`, 여러 통이면 `in`(웹·Android와 같은 질의 모양).
  public func remove(letterIds: [String]) async throws {
    guard !letterIds.isEmpty else { return }
    do {
      let query = provider.client.from("inbox").delete()
      if letterIds.count == 1 {
        try await query.eq("letter_id", value: letterIds[0]).execute()
      } else {
        try await query.in("letter_id", values: letterIds).execute()
      }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func deletedInbox() async throws -> [DeletedInboxItem] {
    do {
      let rows: [DeletedInboxRow] = try await provider.client
        .rpc("get_my_deleted_inbox")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  @discardableResult
  public func restore(letterIds: [String]) async throws -> Int {
    do {
      return try await provider.client
        .rpc("restore_inbox_items", params: LetterIdsParams(letterIds: letterIds))
        .execute()
        .value
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  @discardableResult
  public func purge(letterIds: [String]) async throws -> Int {
    do {
      return try await provider.client
        .rpc("purge_inbox_items", params: LetterIdsParams(letterIds: letterIds))
        .execute()
        .value
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
