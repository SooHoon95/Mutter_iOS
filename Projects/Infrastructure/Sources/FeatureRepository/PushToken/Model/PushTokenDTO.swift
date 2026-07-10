import Foundation

/// upsert_push_token(p_token, p_platform, p_device_id) 파라미터.
/// nil deviceId도 명시 null로 인코딩(JSONEncoder.supabase 규칙).
struct UpsertPushTokenParams: Encodable {
  let token: String
  let platform: String
  let deviceId: String?

  enum CodingKeys: String, CodingKey {
    case token = "p_token"
    case platform = "p_platform"
    case deviceId = "p_device_id"
  }
}
