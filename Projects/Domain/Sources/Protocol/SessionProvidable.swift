import Foundation

/// 캐시된 세션의 동기 조회 계약(쿼리 빌드·UI 게이팅용).
/// 전체 로그인 플로우는 `AuthUsecasable`, 여기선 "지금 누구인가"만 빠르게 본다.
public protocol SessionProvidable {
  /// 현재 로그인 사용자 id(없으면 nil).
  var currentUserId: String? { get }
}
