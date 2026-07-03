import Foundation

import AppFoundation

/// 편지 유스케이스 구현. 음악은 선택 사항(SC 단일 음원, 무음 허용) — cue nil이면 그대로 저장.
public final class LetterUsecase: LetterUsecasable {
  private let repository: LetterRepositorable

  public init(repository: LetterRepositorable) {
    self.repository = repository
  }

  public func create(_ draft: LetterDraft) async throws -> Letter {
    try await repository.create(draft)
  }

  public func update(id: String, _ draft: LetterDraft) async throws {
    try await repository.update(id: id, draft)
  }

  public func letter(id: String) async throws -> Letter? {
    try await repository.letter(id: id)
  }

  public func myLetters() async throws -> [Letter] {
    try await repository.myLetters()
  }

  public func delete(id: String) async throws {
    try await repository.delete(id: id)
  }
}
