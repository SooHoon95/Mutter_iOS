import Foundation

/// 편지 접근 상태 유스케이스 구현. 기간·권한 판정은 서버가 강제하고 여기선 표시용으로 합친다.
public final class LetterAccessUsecase: LetterAccessUsecasable {
  private let repository: LetterAccessRepositorable

  public init(repository: LetterAccessRepositorable) {
    self.repository = repository
  }

  public func cover(token: String) async throws -> LetterCover {
    try await repository.cover(token: token)
  }

  public func accessStates(letterIds: [String]) async throws -> [String: LetterAccessState] {
    guard !letterIds.isEmpty else { return [:] }
    let states = try await repository.accessStates(letterIds: letterIds)
    return Dictionary(states.map { ($0.letterId, $0) }, uniquingKeysWith: { first, _ in first })
  }

  public func readers(letterId: String) async throws -> [LetterReader] {
    try await repository.readers(letterId: letterId)
  }

  public func duplicate(letterId: String) async throws -> String {
    try await repository.duplicate(letterId: letterId)
  }

  public func requestKeep(token: String, password: String?) async throws -> Bool {
    try await repository.requestKeep(token: token, password: password)
  }

  public func keepRequests(letterId: String) async throws -> [LetterKeepRequest] {
    try await repository.keepRequests(letterId: letterId)
  }
}
