import Foundation

/// 편지 데이터 접근 프로토콜(구현은 Infrastructure — `letters` 테이블, paragraphs↔body 변환).
public protocol LetterRepositorable {
  func create(_ draft: LetterDraft) async throws -> Letter
  func update(id: String, _ draft: LetterDraft) async throws
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  /// 내 편지 + 발송 여부(홈 세그먼트용). is_sent = delivery_links 존재 OR 타인 inbox 존재.
  func myLettersWithStatus() async throws -> [LetterWithStatus]
  func delete(id: String) async throws
}
