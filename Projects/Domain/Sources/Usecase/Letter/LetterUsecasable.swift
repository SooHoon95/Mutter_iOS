import Foundation

/// 편지 유스케이스 — CRUD + 사진. 음악(cue)은 선택 사항(SC 단일 음원, 무음 허용).
public protocol LetterUsecasable {
  /// 새 편지 생성. 대기 사진이 있으면 생성 → 업로드 → 경로 반영까지 한다.
  /// 생성 뒤 사진 단계가 실패하면 `LetterPhotoSaveError`를 던진다.
  func create(_ draft: LetterDraft) async throws -> Letter
  /// 기존 편지 수정(이어쓰기 포함). 대기 사진을 올린 뒤 경로가 채워진 블록을 돌려준다.
  /// 업로드가 하나라도 실패하면 `LetterPhotoSaveError`를 던진다(본문 update는 하지 않는다).
  @discardableResult
  func update(id: String, _ draft: LetterDraft) async throws -> [LetterBlock]
  func letter(id: String) async throws -> Letter?
  func myLetters() async throws -> [Letter]
  /// 내 편지 + 발송 여부(홈 세그먼트: 보낸 편지 vs 임시저장 분리).
  func myLettersWithStatus() async throws -> [LetterWithStatus]
  func delete(id: String) async throws
  /// 수신자 모드 사진 서명 URL(path → URL, 1시간 유효).
  func photoURLs(token: String, password: String?) async throws -> [String: URL]
  /// 소유자 모드 사진 서명 URL(path → URL, 1시간 유효).
  func photoURLs(letterId: String) async throws -> [String: URL]
}
