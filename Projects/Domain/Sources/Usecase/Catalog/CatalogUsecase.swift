import Foundation

/// 카탈로그 유스케이스 구현.
public final class CatalogUsecase: CatalogUsecasable {
  private let repository: CatalogRepositorable

  public init(repository: CatalogRepositorable) {
    self.repository = repository
  }

  public func all() async throws -> [Track] {
    try await repository.all()
  }

  public func track(id: String) async throws -> Track? {
    try await repository.track(id: id)
  }

  public func byMood(_ mood: String) async throws -> [Track] {
    try await repository.byMood(mood)
  }
}
