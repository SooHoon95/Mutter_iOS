import Foundation

/// 카탈로그 데이터 접근 프로토콜(구현은 Infrastructure — `tracks` 테이블/번들 카탈로그).
public protocol CatalogRepositorable {
  func all() async throws -> [Track]
  func track(id: String) async throws -> Track?
  func byMood(_ mood: String) async throws -> [Track]
}
