import Foundation

/// 목록 행의 접근 상태 표시(문구 변환은 화면 몫): `영구` / `{n}일 남음` / `닫힘`(자물쇠).
public enum LetterAccessBadgeType: Equatable {
  case permanent
  case daysLeft(Int)
  case locked
}
