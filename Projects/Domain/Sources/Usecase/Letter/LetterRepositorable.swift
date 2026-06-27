import Foundation

/// 편지 데이터 접근 프로토콜(구현은 Infrastructure — `letters` 테이블, paragraphs↔body 변환).
public protocol LetterRepositorable {
  func create(_ draft: LetterDraft) async throws -> Letter
  func update(id: String, _ draft: LetterDraft) async throws
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  func delete(id: String) async throws
}
