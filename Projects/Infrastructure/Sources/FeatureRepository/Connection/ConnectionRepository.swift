import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `ConnectionRepositorable` 구현 — 독점 1:1 연결. 토큰 클라 생성, 배타성은 서버 RPC가 강제.
public final class ConnectionRepository: ConnectionRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func createInvite() async throws -> String {
    let token = TokenGenerator.make()
    do {
      try await provider.client
        .rpc("create_connect_invite", params: TokenParam(token: token))
        .execute()
      return token
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  /// 초대 링크 무효화 — `revoke_connect_invite` RPC (EC-2.8).
  public func revokeInvite(token: String) async throws {
    do {
      try await provider.client
        .rpc("revoke_connect_invite", params: TokenParam(token: token))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func invite(token: String) async throws -> ConnectInvite {
    do {
      let rows: [ConnectInviteRow] = try await provider.client
        .rpc("get_connect_invite", params: TokenParam(token: token))
        .execute()
        .value
      guard let row = rows.first else {
        throw MutterError(.notFound)
      }
      return row.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func accept(token: String) async throws {
    do {
      try await provider.client
        .rpc("accept_connect_invite", params: TokenParam(token: token))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func myConnections() async throws -> [Connection] {
    do {
      let rows: [ConnectionRow] = try await provider.client
        .rpc("get_my_connections")
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func disconnect(otherUserId: String) async throws {
    do {
      try await provider.client
        .rpc("disconnect_connection", params: DisconnectParams(otherUser: otherUserId))
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func send(letterId: String, recipientId: String) async throws {
    do {
      let params = SendToConnectionParams(
        letterId: letterId,
        recipient: recipientId,
        token: TokenGenerator.make()
      )
      try await provider.client
        .rpc("send_to_connection", params: params)
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
