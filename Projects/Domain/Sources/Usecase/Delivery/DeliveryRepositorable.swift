import Foundation

/// 전달 데이터 접근 프로토콜(구현은 Infrastructure — issue_link/get_letter_by_token/revoke_link RPC).
public protocol DeliveryRepositorable {
  /// `permanent`가 true면 서버가 발급과 같은 트랜잭션에서 편지권 1장을 써 영구 편지로 만든다.
  func issue(letterId: String, password: String?, revealAt: Date?, permanent: Bool) async throws -> DeliveryLink
  func revoke(token: String) async throws
  func links(letterId: String) async throws -> [DeliveryLink]
  func open(token: String, password: String?) async throws -> LetterPayload
}
