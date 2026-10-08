import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `LetterPhotoRepositorable` 구현 — 비공개 버킷 `letter-photos` + 서명 URL Edge Function `letter-photo-urls`.
/// 경로 첫 폴더가 소유자 uid라 Storage RLS가 본인 폴더만 쓰기·지우기를 허용한다.
public final class LetterPhotoRepository: LetterPhotoRepositorable {
  private let provider: SupabaseProvider
  private let bucket = "letter-photos"
  private let urlsFunction = "letter-photo-urls"

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  private func currentUserId() throws -> String {
    guard let uid = provider.client.auth.currentUser?.id.uuidString else {
      throw MutterError(.unauthorized)
    }
    // RLS가 auth.uid()::text(소문자 uuid)와 폴더명을 비교하므로 소문자로 맞춘다.
    return uid.lowercased()
  }

  private func folder(letterId: String) throws -> String {
    "\(try currentUserId())/\(letterId.lowercased())"
  }

  public func upload(jpeg: Data, letterId: String) async throws -> String {
    let path = "\(try folder(letterId: letterId))/\(UUID().uuidString.lowercased()).jpg"
    do {
      _ = try await provider.client.storage
        .from(bucket)
        .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: false))
      return path
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func storedPaths(letterId: String) async throws -> [String] {
    let folder = try folder(letterId: letterId)
    do {
      let objects = try await provider.client.storage.from(bucket).list(path: folder)
      return objects.map { "\(folder)/\($0.name)" }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func delete(paths: [String]) async throws {
    guard !paths.isEmpty else { return }
    do {
      _ = try await provider.client.storage.from(bucket).remove(paths: paths)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func deleteAll(letterId: String) async throws {
    try await delete(paths: storedPaths(letterId: letterId))
  }

  public func signedURLs(token: String, password: String?) async throws -> [String: URL] {
    try await invokeURLs(LetterPhotoURLsTokenRequest(token: token, password: password))
  }

  public func signedURLs(letterId: String) async throws -> [String: URL] {
    try await invokeURLs(LetterPhotoURLsOwnerRequest(letterId: letterId))
  }

  private func invokeURLs(_ body: some Encodable) async throws -> [String: URL] {
    do {
      let response: LetterPhotoURLsResponse = try await provider.client.functions.invoke(
        urlsFunction,
        options: FunctionInvokeOptions(body: body)
      )
      return response.toDomain()
    } catch FunctionsError.httpError(let code, _) where code == 403 {
      // 링크 회수·만료·암호 불일치·남의 편지 — 함수가 403으로 통일해 돌려준다. 세션 만료 신호가 아니다.
      throw MutterError(.unauthorized)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
