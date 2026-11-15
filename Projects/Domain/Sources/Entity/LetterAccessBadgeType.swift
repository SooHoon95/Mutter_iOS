import Foundation

/// 목록 행의 접근 상태 표시(문구 변환은 화면 몫): `영구` / `{n}일 남음` / 자물쇠 + `{n}일 뒤 삭제`.
public enum LetterAccessBadgeType: Equatable {
  case permanent
  case daysLeft(Int)
  /// 닫힌 편지. `deleteInDays`는 삭제까지 남은 달력 일수(0 = 오늘, nil = 삭제 시각을 모름).
  case locked(deleteInDays: Int?)
}
