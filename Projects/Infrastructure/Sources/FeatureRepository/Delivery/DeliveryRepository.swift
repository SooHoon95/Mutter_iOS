import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `DeliveryRepositorable` 구현 — 토큰은 클라이언트 생성(capability-links), 접근통제는 서버 RPC/RLS.
public final class DeliveryRepository: DeliveryRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func issue(letterId: String, password: String?, revealAt: Date?) async throws -> DeliveryLink {
    do {
      let params = IssueLinkParams(
        letterId: letterId,
        token: TokenGenerator.make(),
        password: password,
        expiresAt: nil,
        revealAt: revealAt.map(ISO8601.string(from:))
      )
      // issue_link는 setof 반환 → 첫 행.
      let rows: [RpcDeliveryLinkRow] = try await provider.client
        .rpc("issue_link", params: params)
        .execute()
        .value
      guard let row = rows.first else {
        throw MutterError(.server("링크 발급 응답이 비어 있어요."))
      }
      return row.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func revoke(token: String) async throws {
    do {
      try await provider.client
        .rpc("revoke_link", params: TokenParam(token: token))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func links(letterId: String) async throws -> [DeliveryLink] {
    do {
      // password_hash 원문은 select하지 않는다(클라이언트 비노출). has_password 생성 컬럼만.
      let rows: [DeliveryLinkRow] = try await provider.client
        .from("delivery_links")
        .select("letter_id, token, has_password, expires_at, reveal_at, revoked")
        .eq("letter_id", value: letterId)
        .order("created_at", ascending: false)
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func open(token: String, password: String?) async throws -> LetterPayload {
    do {
      // get_letter_by_token은 단일 객체 반환(토큰·revoke·expiry·암호·예약공개 게이트를 서버가 검증).
      let payload: LetterPayloadDTO = try await provider.client
        .rpc("get_letter_by_token", params: OpenLinkParams(token: token, password: password))
        .execute()
        .value
      return payload.toDomain()
    } catch {
      // NOT_YET_REVEALED:<ISO>·WRONG_PASSWORD·LINK_REVOKED 등을 도메인 에러로 정규화.
      throw SupabaseErrorMapper.map(error)
    }
  }
}
