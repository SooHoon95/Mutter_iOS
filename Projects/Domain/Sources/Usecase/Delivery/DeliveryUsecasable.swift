import Foundation

/// 전달 유스케이스 — 링크 발급(암호 ON·예약공개)·열람·revoke.
public protocol DeliveryUsecasable {
  /// 링크 발급. password nil이면 호출부 기본정책(암호 ON)을 따른다. revealAt=예약공개.
  /// `permanent`가 true면 서버가 발급과 같은 트랜잭션에서 편지권 1장을 써 영구 편지로 만든다.
  func issue(letterId: String, password: String?, revealAt: Date?, permanent: Bool) async throws -> DeliveryLink
  func revoke(token: String) async throws
  func links(letterId: String) async throws -> [DeliveryLink]
  /// 토큰으로 열람. 예약 전이면 `linkNotYetRevealed`, 암호 불일치면 `wrongPassword`.
  func open(token: String, password: String?) async throws -> LetterPayload
}
