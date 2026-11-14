import Foundation

import Supabase

import AppFoundation

/// Supabase 접속의 단일 진입점(데이터 레이어 경계).
///
/// ## 왜 이 타입이 존재하나
/// `supabase-swift`의 `SupabaseClient`는 인증(`auth`)·DB(`from`/`rpc`)·Edge Function(`functions`)·
/// Storage를 한 객체로 묶는다. 앱 전역에서 클라이언트를 매번 새로 만들면 세션·커넥션이 분산되므로,
/// **하나의 구성된 클라이언트**를 이 Provider가 보유하고 Infrastructure 레이어의 Repository들이 공유한다.
///
/// ## 클라이언트 구성 방법
/// - `supabaseURL` / `supabaseKey`(anon key)는 소스에 하드코딩하지 않고 `AppConfig`(xcconfig→Info.plist)에서 읽는다.
/// - `options`는 기본값(`SupabaseClientOptions()`)을 쓴다. 이 기본 구성에서 **인증 세션은 자동으로
///   Keychain(`KeychainLocalStorage`)에 안전 저장**되고, 토큰 자동 갱신(autoRefresh)도 켜진다.
///   → 별도 Keychain 코드를 우리가 작성할 필요가 없다(SDK 기본이 곧 스펙의 "세션 Keychain 보관").
///
/// ## 노출 표면
/// Repository는 `provider.client`를 통해 `client.auth`, `client.from("table")`, `client.rpc("fn")`,
/// `client.functions`에 직접 접근한다. PostgREST 빌더(`.select()`·`.eq()`·`.execute()`)를 그대로 쓰기 위해
/// 클라이언트를 얇게 노출한다(빌더 메서드를 일일이 감싸지 않는다).
public final class SupabaseProvider {
  /// 앱 전역 공유 인스턴스. 합성 루트(MutterApp)에서 `MutterContainer`에 등록해 주입한다.
  public static let shared = SupabaseProvider()

  /// 구성된 Supabase 클라이언트(인증·DB·RPC·Function·Storage 통합 진입점).
  public let client: SupabaseClient

  /// - Parameters:
  ///   - url: Supabase 프로젝트 URL. 기본값은 `AppConfig`(환경 주입)에서 읽는다.
  ///   - anonKey: 공개 anon key(클라이언트 노출 허용 값). service_role 키는 절대 클라이언트에 두지 않는다.
  public init(
    url: URL = AppConfig.supabaseURL,
    anonKey: String = AppConfig.supabaseAnonKey
  ) {
    // 기본 옵션: 인증 세션 = Keychain, 토큰 자동 갱신 ON.
    // emitLocalSessionAsInitialSession: SDK가 다음 메이저에서 기본값으로 바꾸는 동작을 미리 켠다 — 저장된 세션을
    // 갱신을 기다리지 않고 초기 세션으로 바로 내보낸다. 켜지 않으면 실행할 때마다 콘솔에 경고가 찍힌다.
    // 이 앱은 초기 세션 이벤트(authStateChanges)를 구독하지 않는다 — 로그인 여부는 `auth.currentSession`(로컬 캐시)으로
    // 판단하고, 실제 요청의 토큰은 SDK가 갱신해 보낸다. 그래서 이 옵션으로 동작이 달라지는 곳은 없다.
    self.client = SupabaseClient(
      supabaseURL: url,
      supabaseKey: anonKey,
      options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
    )

    // Pulse 네트워크 로깅을 켠다(URLSession 자동 후킹 — Supabase 트래픽 포함).
    NetworkLogging.enable()
  }
}
