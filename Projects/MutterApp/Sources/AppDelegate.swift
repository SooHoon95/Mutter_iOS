import UIKit
import UserNotifications

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
    requestPushAuthorization(application)
    return true
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
