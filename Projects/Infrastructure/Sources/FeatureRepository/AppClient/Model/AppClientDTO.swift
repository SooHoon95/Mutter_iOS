import Foundation

/// report_app_client(p_platform, p_app_version, p_build) 파라미터.
/// nil build도 명시 null로 인코딩(JSONEncoder.supabase 규칙).
struct ReportAppClientParams: Encodable {
  let platform: String
  let appVersion: String
  let build: String?

  enum CodingKeys: String, CodingKey {
    case platform = "p_platform"
    case appVersion = "p_app_version"
    case build = "p_build"
  }
}
