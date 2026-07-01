import Foundation

/// 환경 설정값. Supabase 자격값은 xcconfig(`Sensitive.xcconfig`) → Info.plist 경유로 주입되며,
/// 소스에 하드코딩하지 않는다.
public enum AppConfig {
  public static var supabaseURL: URL {
    guard let url = URL(string: infoString("SUPABASE_URL")) else {
      fatalError("AppConfig: SUPABASE_URL 형식 오류")
    }
    return url
  }

  public static var supabaseAnonKey: String {
    infoString("SUPABASE_ANON_KEY")
  }

  /// Google OAuth 클라이언트 ID(없으면 nil — 소셜 로그인 비활성). Sensitive.xcconfig에서 주입.
  public static var googleClientID: String? { optionalInfoString("GOOGLE_CLIENT_ID") }

  /// Kakao 네이티브 앱 키(없으면 nil). Sensitive.xcconfig에서 주입.
  public static var kakaoAppKey: String? { optionalInfoString("KAKAO_APP_KEY") }

  private static func infoString(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
      fatalError("AppConfig: Info.plist '\(key)' 누락 — Sensitive.xcconfig 확인")
    }
    return value
  }

  /// 선택적 설정값 — 없거나 비면 nil(치명적 아님).
  private static func optionalInfoString(_ key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
      return nil
    }
    return value
  }
}
