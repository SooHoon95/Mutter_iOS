import Foundation

public final class PushTokenUsecase: PushTokenUsecasable {
  private let repository: PushTokenRepositorable

  public init(repository: PushTokenRepositorable) {
    self.repository = repository
  }

  public func register(token: String, deviceId: String?) async throws {
    try await repository.upsert(token: token, platform: "ios", deviceId: deviceId)
  }
}
