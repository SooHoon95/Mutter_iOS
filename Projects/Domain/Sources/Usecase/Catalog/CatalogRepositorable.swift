import Foundation

/// 카탈로그 데이터 접근 프로토콜(구현은 Infrastructure — `tracks` 테이블/번들 카탈로그).
public protocol CatalogRepositorable {
  func all() async throws -> [Track]
  func track(id: String) async throws -> Track?
  func byMood(_ mood: String) async throws -> [Track]
  /// 호스팅 트랙의 이식가능 ref(예 `/audio/x.m4a`)를 로컬 번들 파일 URL로 해석.
  /// cue ref는 웹/수신자와 호환되게 상대경로로 유지하고 재생 시점에만 플랫폼별로 해석한다.
  /// 번들에 없으면 nil(원격 URL은 그대로 스트리밍). 기본 nil — 테스트 더블·원격 전용 구현 보호.
  func localAudioURL(for ref: String) -> URL?
}

public extension CatalogRepositorable {
  func localAudioURL(for ref: String) -> URL? { nil }
}
