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

  private static func infoString(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
      fatalError("AppConfig: Info.plist '\(key)' 누락 — Sensitive.xcconfig 확인")
    }
    return value
  }
}
