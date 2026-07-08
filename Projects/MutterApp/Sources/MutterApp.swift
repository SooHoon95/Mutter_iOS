import SwiftUI
import UserNotifications

import AppFoundation
import Domain
import Infrastructure
import UIComponent

import GoogleSignIn
import KakaoSDKCommon

import FirebaseCore
import FirebaseMessaging

/// 앱 진입점. 의존성 등록은 `AppDelegate.didFinishLaunching`에서 1회 수행하고,
/// 루트 화면(splash→signin→maintab)은 `MainView`가 맡는다(Mercury `MercuryApp` 패턴).
@main
struct MutterApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    WindowGroup {
      OverlayWindowView {
        MainView()
          .environment(NetworkMonitor.shared)
          .onOpenURL { url in
            OauthDeepLinkHandler.shared.handle(url: url)
          }
      }
    }
  }
}

/// 앱 델리게이트 — Firebase 초기화 + 원격 푸시(APNs/FCM) 배선. `@UIApplicationDelegateAdaptor`로 연결.
///
/// 현재: `FirebaseApp.configure()`(GoogleService-Info.plist)로 Analytics·Crashlytics·Messaging 활성 +
/// APNs 권한 요청·등록 + FCM 등록 토큰 수신(로그).
/// 다음 단계: `push_tokens` 스키마 확정 후 FCM 토큰을 `PushTokenService`로 Supabase에 등록
/// (Mercury `FcmTokenUsecase.sendFcmToken` 패턴).
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    
    // 전역(앱 전체 공유) 의존성만 1회 등록(SwiftUI body 이전). didFinishLaunching은 메인 스레드.
    MainActor.assumeIsolated {
      registerGlobalDependencies()
      configureGoogleInstance()
      configureKakaoLoginInstance()
    }
    configFirebase(application)
    return true
  }

  /// 소셜 로그인 SDK 초기화 — 키가 있을 때만(Sensitive.xcconfig 미설정 시 조용히 건너뜀).
  @MainActor
  private func configureGoogleInstance() {
    if let clientID = AppConfig.googleClientID {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
   
  }

  private func configureKakaoLoginInstance() {
    if let appKey = AppConfig.kakaoAppKey {
      KakaoSDK.initSDK(appKey: appKey)
    }
  }

  /// Firebase 초기화 + 푸시 배선(Mercury `configFirebase` 패턴).
  /// `FirebaseApp.configure()`가 GoogleService-Info.plist를 읽어 Analytics·Crashlytics·Messaging을 켠다.
  private func configFirebase(_ application: UIApplication) {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    requestPushAuthorization(application)
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
    // APNs 토큰을 FCM에 전달(Mercury 패턴) → 이후 MessagingDelegate가 FCM 등록 토큰을 콜백.
    Messaging.messaging().apnsToken = deviceToken
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

// MARK: - 포그라운드 알림 표시 (Mercury 패턴)
extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}

// MARK: - FCM 등록 토큰 수신 (Mercury 패턴)
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // 다음 단계: push_tokens 스키마 확정 후 PushTokenService로 Supabase에 등록
    // (Mercury FcmTokenUsecase.sendFcmToken 패턴).
    print("[Push] FCM registration token: \(fcmToken ?? "nil")")
  }
}
