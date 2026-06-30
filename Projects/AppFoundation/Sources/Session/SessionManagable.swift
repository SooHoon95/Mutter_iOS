import Combine

/// 로그인 세션 상태 관리 계약(Mercury `AccessTokenManagable` 대응).
/// 합성 루트가 구현체를 `MutterContainer`에 등록하고, `MainView`가 `@Inject`로 받아
/// `isLoggedInStream`을 구독해 splash→signin→maintab 단계를 전환한다.
/// 현재는 Supabase 세션 기반(로그인 여부 Bool). 추후 토큰/소셜 로그인으로 확장하는 seam.
/// 스트림은 SwiftUI(`MainView`)가 구독하므로 메인 액터에 고정한다.
@MainActor
public protocol SessionManagable: AnyObject {
  /// 로그인 상태 스트림. 구독 즉시 현재값을 방출한다(CurrentValue 기반).
  var isLoggedInStream: AnyPublisher<Bool, Never> { get }
  /// 마지막으로 산출된 로그인 여부(동기 조회용).
  var isLoggedIn: Bool { get }
  /// 현재 세션을 재확인해 스트림을 갱신한다(앱 시작·로그인/로그아웃 직후 호출).
  func refresh() async
  /// 로그아웃 후 세션 상태를 미로그인으로 갱신한다.
  func signOut() async
}
