import Foundation

/// 편지 데이터 접근 프로토콜(구현은 Infrastructure — `letters` 테이블, paragraphs↔body 변환).
public protocol LetterRepositorable {
  func create(_ draft: LetterDraft) async throws -> Letter
  func update(id: String, _ draft: LetterDraft) async throws
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  /// 내 편지 + 발송 여부(홈 세그먼트용). is_sent = delivery_links 존재 OR 타인 inbox 존재.
  func myLettersWithStatus() async throws -> [LetterWithStatus]
  /// 삭제(보관 처리). 서버 뷰 트리거가 실제 삭제 대신 `deleted_at`을 찍는다.
  func delete(id: String) async throws
  /// 삭제함 — 보관 중인 내 편지(최근 삭제순).
  func deletedLetters() async throws -> [DeletedLetter]
  /// 보관 중인 편지를 되살린다(링크·상대 보관함도 함께 돌아온다).
  func restore(id: String) async throws
  /// 보관 중인 편지를 영구 삭제한다(되돌릴 수 없음). 사진 정리는 호출부 몫.
  func purge(id: String) async throws
}
