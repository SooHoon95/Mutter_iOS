import Foundation

/// 전달 유스케이스 — 링크 발급(암호 ON·예약공개)·열람·revoke.
public protocol DeliveryUsecasable {
  /// 링크 발급. password nil이면 호출부 기본정책(암호 ON)을 따른다. revealAt=예약공개.
  func issue(letterId: String, password: String?, revealAt: Date?) async throws -> DeliveryLink
  func revoke(token: String) async throws
  func links(letterId: String) async throws -> [DeliveryLink]
  /// 토큰으로 열람. 예약 전이면 `linkNotYetRevealed`, 암호 불일치면 `wrongPassword`.
  func open(token: String, password: String?) async throws -> LetterPayload
}
