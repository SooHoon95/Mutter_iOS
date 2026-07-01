import SwiftUI
import UserNotifications

import AppFoundation
import Domain
import Infrastructure

import GoogleSignIn
import KakaoSDKCommon

/// 앱 진입점. 의존성 등록은 `AppDelegate.didFinishLaunching`에서 1회 수행하고,
/// 루트 화면(splash→signin→maintab)은 `MainView`가 맡는다(Mercury `MercuryApp` 패턴).
@main
struct MutterApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    WindowGroup {
      MainView()
    }
  }
}

/// 앱 델리게이트 — 원격 푸시(APNs) 등록. SwiftUI App에 `@UIApplicationDelegateAdaptor`로 연결한다.
///
/// 현재: 권한 요청 + APNs 토큰 수신(로그).
/// 다음 단계(보류): GoogleService-Info.plist 추가 → `FirebaseApp.configure()` → FCM 토큰을
/// `PushTokenService`로 Supabase `push_tokens`에 등록(스키마 확정 후).
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    
    // 전역(앱 전체 공유) 의존성만 1회 등록(SwiftUI body 이전). didFinishLaunching은 메인 스레드.
    MainActor.assumeIsolated {
      registerGlobalDependencies()
      configureSocialSDKs()
    }
    requestPushAuthorization(application)
    return true
  }

  /// 소셜 로그인 SDK 초기화 — 키가 있을 때만(Sensitive.xcconfig 미설정 시 조용히 건너뜀).
  @MainActor
  private func configureSocialSDKs() {
    if let clientID = AppConfig.googleClientID {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
    if let appKey = AppConfig.kakaoAppKey {
      KakaoSDK.initSDK(appKey: appKey)
    }
  }

  /// 서비스 로케이터엔 **진짜 전역인 것만** 등록한다(Mercury 패턴 — 세션 등).
  /// usecase/repository는 컨테이너에 넣지 않고 호출부(ViewWrapper·RootViewFactory)에서 생성자 주입한다.
  @MainActor
  private func registerGlobalDependencies() {
    MutterContainer.shared.register(
      SessionManagable.self,
      instance: SessionManager(authUsecase: AuthUsecase(repository: AuthRepository()))
    )
  }
  
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    // TODO: FCM 연동 후 PushTokenService로 push_tokens 테이블에 등록.
    print("[Push] APNs device token: \(token)")
  }
  
  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[Push] APNs 등록 실패: \(error.localizedDescription)")
  }
  
  private func requestPushAuthorization(_ application: UIApplication) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }
}
