import Foundation

import AppFoundation

/// 새 소식 안내를 띄울지 기억하는 값(없음 → pending → seen). 사양 `docs/specs/2026-11-15-whats-new.md` "언제 뜨나".
/// 기기마다 한 번이다 — 새로 설치한 사람에게는 띄우지 않고, 이전 버전을 쓰던 사람만 대상으로 적어 둔다.
enum WhatsNewStore {
  private static let pending = "pending"
  private static let seen = "seen"
  private static var key: String { UserDefaultsKey.whatsNewTickets.rawValue }

  /// 스플래시가 끝나 세션 확인이 된 시점에 부른다. 값이 없을 때만 정한다 —
  /// 이 버전을 처음 열었는데 이미 로그인돼 있으면 이전 버전을 쓰던 사람이다(대상), 아니면 새로 설치한 사람으로 본다.
  static func markBaselineIfNeeded(isLoggedIn: Bool) {
    guard UserDefaults.standard.string(forKey: key) == nil else { return }
    UserDefaults.standard.set(isLoggedIn ? pending : seen, forKey: key)
  }

  /// 아직 보여 주지 않은 대상인지.
  static var isPending: Bool { UserDefaults.standard.string(forKey: key) == pending }

  static func markSeen() {
    UserDefaults.standard.set(seen, forKey: key)
  }
}
