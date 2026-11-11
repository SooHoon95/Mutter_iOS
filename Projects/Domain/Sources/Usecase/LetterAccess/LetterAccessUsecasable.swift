import Foundation

/// 편지 접근 상태 유스케이스 — 봉투·목록 상태·열람자·사본 보내기.
public protocol LetterAccessUsecasable {
  func cover(token: String) async throws -> LetterCover
  /// letterId → 상태. 빈 입력이면 호출하지 않는다.
  func accessStates(letterIds: [String]) async throws -> [String: LetterAccessState]
  func readers(letterId: String) async throws -> [LetterReader]
  func duplicate(letterId: String) async throws -> String
}
