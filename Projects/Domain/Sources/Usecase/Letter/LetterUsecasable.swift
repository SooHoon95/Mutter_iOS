import Foundation

/// 편지 유스케이스 — CRUD. 음악(cue)은 선택 사항(SC 단일 음원, 무음 허용).
public protocol LetterUsecasable {
  /// 새 편지 생성.
  func create(_ draft: LetterDraft) async throws -> Letter
  /// 기존 편지 수정(이어쓰기 포함).
  func update(id: String, _ draft: LetterDraft) async throws
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  func delete(id: String) async throws
}
