import Foundation

/// UserDefaults 키 모음. 문자열 매직값을 한 곳에 둔다.
public enum UserDefaultsKey: String {
  case didOnboard
  case lastNickname
  /// 새 소식 안내(편지권)를 보여 줄지 — 없음 → pending → seen.
  case whatsNewTickets
}
