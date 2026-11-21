import Foundation

public final class AppClientUsecase: AppClientUsecasable {
  private let repository: AppClientRepositorable

  public init(repository: AppClientRepositorable) {
    self.repository = repository
  }

  public func report(appVersion: String, build: String?) async throws {
    try await repository.report(platform: "ios", appVersion: appVersion, build: build)
  }
}
