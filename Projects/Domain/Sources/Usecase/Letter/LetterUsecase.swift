import Foundation

import AppFoundation

/// 편지 유스케이스 구현. 저장 경로에서 무음0(ensureCue)을 강제한다.
public final class LetterUsecase: LetterUsecasable {
  private let repository: LetterRepositorable
  private let catalog: CatalogRepositorable

  public init(repository: LetterRepositorable, catalog: CatalogRepositorable) {
    self.repository = repository
    self.catalog = catalog
  }

  public func create(_ draft: LetterDraft) async throws -> Letter {
    var prepared = draft
    prepared.cue = try await ensureCue(draft.cue)
    return try await repository.create(prepared)
  }

  public func update(id: String, _ draft: LetterDraft) async throws {
    var prepared = draft
    prepared.cue = try await ensureCue(draft.cue)
    try await repository.update(id: id, prepared)
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

  public func ensureCue(_ cue: MusicCue?) async throws -> MusicCue {
    if let cue {
      return cue
    }
    // 무음0: 미선택 시 카탈로그 첫 CC0를 기본 큐로 채운다.
    let tracks = try await catalog.all()
    guard let first = tracks.first else {
      throw MutterError(.server("기본 음악을 불러올 수 없어요."))
    }
    return MusicCue.hosted(from: first)
  }
}
