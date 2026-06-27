import Foundation

/// 편지 유스케이스 — CRUD + 무음0 보장(ensureCue).
public protocol LetterUsecasable {
  /// 새 편지 생성. 저장 전 cue를 보장(무음0).
  func create(_ draft: LetterDraft) async throws -> Letter
  /// 기존 편지 수정(이어쓰기 포함). cue를 보장.
  func update(id: String, _ draft: LetterDraft) async throws
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  func delete(id: String) async throws
  /// 큐가 없으면 기본 CC0로 채운다(무음 편지 0 불변식).
  func ensureCue(_ cue: MusicCue?) async throws -> MusicCue
}
