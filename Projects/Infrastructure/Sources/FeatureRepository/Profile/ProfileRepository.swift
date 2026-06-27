import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `ProfileRepositorable` 구현 — profiles 테이블 + delete_my_account RPC.
public final class ProfileRepository: ProfileRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func myProfile() async throws -> Profile? {
    guard let uid = provider.client.auth.currentUser?.id.uuidString else {
      throw MutterError(.unauthorized)
    }
    do {
      // RLS만 의존하지 않고 id를 명시 필터(타인 행 누설 방지). 0행이면 nil.
      let rows: [ProfileDTO] = try await provider.client
        .from("profiles")
        .select()
        .eq("id", value: uid)
        .limit(1)
        .execute()
        .value
      return rows.first?.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func updateNickname(_ nickname: String) async throws {
    guard let uid = provider.client.auth.currentUser?.id.uuidString else {
      throw MutterError(.unauthorized)
    }
    do {
      // upsert: 프로필 행 유무와 무관하게 동작(가입 트리거 의존 제거). RLS가 본인 행만 허용.
      let payload = ProfileUpsertDTO(
        id: uid,
        nickname: nickname,
        updatedAt: ISO8601.string(from: Date())
      )
      try await provider.client
        .from("profiles")
        .upsert(payload, onConflict: "id")
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func deleteAccount() async throws {
    do {
      // 서버 RPC가 Cascade로 소유 데이터를 원자적으로 정리한다(클라이언트 직접 delete 금지).
      try await provider.client
        .rpc("delete_my_account")
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
