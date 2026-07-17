import Foundation

/// 수락 완료한 초대 토큰을 로컬에 기억한다.
///
/// ## 왜 필요한가
/// 초대 토큰은 서버에서 단일 사용이라, 첫 수락으로 연결이 생성되면 토큰이 소비된다.
/// 이후 같은 링크(카톡 등)를 다시 열면 `get_connect_invite`가 소비된 토큰을 거부해
/// "만료"로 오인 표시되지만 실제 연결은 이미 성사돼 있다.
/// 이 스토어가 "이 토큰은 이미 내가 수락했다"를 기억해, 재오픈 시 서버 재확인 없이
/// 연결 완료 상태를 보여주게 한다(멱등 처리).
enum AcceptedInviteStore {
  private static let key = "mutter.accepted_invite_tokens"

  static func contains(_ token: String) -> Bool {
    tokens().contains(token)
  }

  static func markAccepted(_ token: String) {
    var set = tokens()
    set.insert(token)
    UserDefaults.standard.set(Array(set), forKey: key)
  }

  private static func tokens() -> Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
  }
}
