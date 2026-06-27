import Foundation

/// CC0/RF 카탈로그 유스케이스 — 무드 픽커·기본 폴백 소스.
public protocol CatalogUsecasable {
  func all() async throws -> [Track]
  func track(id: String) async throws -> Track?
  func byMood(_ mood: String) async throws -> [Track]
}
