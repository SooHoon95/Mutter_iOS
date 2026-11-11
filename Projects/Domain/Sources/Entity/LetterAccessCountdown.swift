import Foundation

/// 남은 기간 계산 규칙(세 플랫폼 공통). 일수 경계는 기기 달력의 자정 기준이다.
public enum LetterAccessCountdown {
  /// 받은 사람에게 "곧 닫혀요" 한 줄을 띄우는 남은 일수 상한(계약: 남은 기간 ≤ 3일).
  public static let closingSoonDays = 3

  /// 오늘부터 `date`까지 남은 달력 일수(같은 날 = 0, 지났으면 0).
  public static func days(until date: Date, from now: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: now)
    let end = calendar.startOfDay(for: date)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
  }
}
