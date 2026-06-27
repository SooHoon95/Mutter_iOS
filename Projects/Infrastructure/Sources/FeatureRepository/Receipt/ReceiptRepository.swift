import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `ReceiptRepositorable` 구현 — 읽음확인 기록/롤업.
public final class ReceiptRepository: ReceiptRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func recordOpen(token: String) async throws {
    do {
      // anon 호출 허용. 무효/만료 링크면 서버가 조용히 no-op(상태 누설 방지).
      try await provider.client
        .rpc("record_letter_open", params: TokenParam(token: token))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func myLetterOpens() async throws -> [LetterOpenSummary] {
    do {
      let rows: [LetterOpenRow] = try await provider.client
        .rpc("get_my_letter_opens")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
