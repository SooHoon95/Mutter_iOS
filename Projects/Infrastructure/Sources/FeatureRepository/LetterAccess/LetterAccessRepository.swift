import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `LetterAccessRepositorable` 구현 — 봉투·접근 상태·열람자·간직 요청(RPC), 사본 보내기(Edge Function).
public final class LetterAccessRepository: LetterAccessRepositorable {
  private let provider: SupabaseProvider
  private let duplicateFunction = "duplicate-letter"

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func cover(token: String) async throws -> LetterCover {
    do {
      let dto: LetterCoverDTO = try await provider.client
        .rpc("get_letter_cover", params: TokenParam(token: token))
        .execute()
        .value
      return dto.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func accessStates(letterIds: [String]) async throws -> [LetterAccessState] {
    do {
      let rows: [LetterAccessStateRow] = try await provider.client
        .rpc("get_letter_access_states", params: LetterIdsParams(letterIds: letterIds))
        .execute()
        .value
      return rows.compactMap { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func readers(letterId: String) async throws -> [LetterReader] {
    do {
      let rows: [LetterReaderRow] = try await provider.client
        .rpc("get_letter_readers", params: LetterIdParams(letterId: letterId))
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func requestKeep(token: String, password: String?) async throws -> Bool {
    do {
      // p_password는 암호가 없어도 null로 명시해 보낸다(생략하면 PostgREST가 함수를 못 찾는다).
      let notified: Bool = try await provider.client
        .rpc("request_keep_letter", params: OpenLinkParams(token: token, password: password))
        .execute()
        .value
      return notified
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func keepRequests(letterId: String) async throws -> [LetterKeepRequest] {
    do {
      let rows: [LetterKeepRequestRow] = try await provider.client
        .rpc("get_letter_keep_requests", params: LetterIdParams(letterId: letterId))
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func duplicate(letterId: String) async throws -> String {
    do {
      let response: DuplicateLetterResponse = try await provider.client.functions.invoke(
        duplicateFunction,
        options: FunctionInvokeOptions(body: DuplicateLetterRequest(letterId: letterId))
      )
      return response.letterId
    } catch FunctionsError.httpError(let code, _) where code == 404 {
      // letter_not_found — 남의 편지 포함.
      throw MutterError(.notFound)
    } catch FunctionsError.httpError(let code, _) where code == 401 {
      throw MutterError(.unauthorized)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
