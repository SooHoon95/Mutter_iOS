import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// `LetterRepositorable` 구현 — letters 테이블 CRUD. paragraphs↔body 변환은 `LetterContentCodec`.
public final class LetterRepository: LetterRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  private func currentUserId() throws -> String {
    guard let uid = provider.client.auth.currentUser?.id.uuidString else {
      throw MutterError(.unauthorized)
    }
    return uid
  }

  public func create(_ draft: LetterDraft) async throws -> Letter {
    let uid = try currentUserId()
    do {
      let dto = LetterInsertDTO(
        ownerId: uid,
        title: draft.title,
        paragraphs: LetterContentCodec.paragraphs(body: draft.body, cue: draft.cue),
        templateId: draft.templateId
      )
      let row: LetterRow = try await provider.client
        .from("letters")
        .insert(dto)
        .select()
        .single()
        .execute()
        .value
      return row.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func update(id: String, _ draft: LetterDraft) async throws {
    do {
      let dto = LetterUpdateDTO(
        title: draft.title,
        paragraphs: LetterContentCodec.paragraphs(body: draft.body, cue: draft.cue),
        templateId: draft.templateId,
        updatedAt: ISO8601.string(from: Date())
      )
      // RLS가 owner_id = auth.uid()를 강제 — 타계정 편지는 0행 매칭으로 거부된다.
      try await provider.client
        .from("letters")
        .update(dto)
        .eq("id", value: id)
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func letter(id: String) async throws -> Letter? {
    do {
      let rows: [LetterRow] = try await provider.client
        .from("letters")
        .select()
        .eq("id", value: id)
        .limit(1)
        .execute()
        .value
      return rows.first?.toDomain()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func myLetters() async throws -> [Letter] {
    let uid = try currentUserId()
    do {
      let rows: [LetterRow] = try await provider.client
        .from("letters")
        .select()
        .eq("owner_id", value: uid)
        .order("updated_at", ascending: false)
        .execute()
        .value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }

  public func delete(id: String) async throws {
    do {
      try await provider.client
        .from("letters")
        .delete()
        .eq("id", value: id)
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
