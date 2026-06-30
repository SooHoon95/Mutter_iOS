import Foundation

import Domain

/// `CatalogRepositorable` 구현 — 번들된 CC0 카탈로그(tracks.json).
/// 무음0: 카탈로그는 절대 비어선 안 된다(폴백 음원 소실 방지). 로드 1회 캐시.
public final class CatalogRepository: CatalogRepositorable {
  private let tracks: [Track]

  public init() {
    self.tracks = Self.loadBundledCatalog()
  }

  public func all() async throws -> [Track] {
    tracks
  }

  public func track(id: String) async throws -> Track? {
    tracks.first { $0.id == id }
  }

  public func byMood(_ mood: String) async throws -> [Track] {
    tracks.filter { $0.mood == mood }
  }

  /// `/audio/pixabay-calm-001.m4a` → 번들된 CC0 음원 파일 URL.
  /// (이미 절대 URL이면 nil 반환 → 호출부가 원격 스트리밍으로 폴백.)
  public func localAudioURL(for ref: String) -> URL? {
    if let scheme = URL(string: ref)?.scheme, !scheme.isEmpty { return nil } // http(s) 등 절대 URL은 그대로.
    let filename = (ref as NSString).lastPathComponent
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    guard !name.isEmpty, !ext.isEmpty else { return nil }
    return Bundle.module.url(forResource: name, withExtension: ext)
      ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "audio")
  }

  private static func loadBundledCatalog() -> [Track] {
    guard
      let url = Bundle.module.url(forResource: "tracks", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let entries = try? JSONDecoder().decode([CatalogEntryDTO].self, from: data)
    else {
      // 무음0 위반은 치명적 — 개발 중 즉시 인지(릴리스에선 빈 배열 → defaultCue가 에러로 승격).
      assertionFailure("CC0 카탈로그(tracks.json) 로드 실패 — 무음 편지 0 위반")
      return []
    }
    return entries.map { $0.toDomain() }
  }
}
