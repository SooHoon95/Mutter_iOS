import Combine
import Foundation

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

/// 세션 무효(서버 401 — JWT 만료/무효) 전역 신호.
///
/// 인증이 필요한 호출이 서버에서 401을 받으면(= 세션이 죽음) 데이터 레이어(`SupabaseErrorMapper`)가
/// 이 신호를 방송하고, 세션 상태의 단일 소스(`SessionManager`)가 받아 로그아웃 처리한다
/// → `MainView`가 온보딩(signin) 단계로 전환한다. (웹 `revalidateSession`의 401→signOut 대응.)
///
/// 비즈니스 권한 오류(FORBIDDEN 등 403)는 세션 무효가 아니므로 이 신호를 쏘지 않는다.
public enum SessionInvalidation {
  /// 세션이 서버에서 무효(401)로 판정됐을 때 방송되는 알림.
  public static let didDetectUnauthorized = Notification.Name("com.efreedom.mutter.session.didDetectUnauthorized")

  /// 세션 무효(401)를 전역에 알린다. 데이터 레이어에서만 호출한다.
  public static func notifyUnauthorized() {
    NotificationCenter.default.post(name: didDetectUnauthorized, object: nil)
  }
}
