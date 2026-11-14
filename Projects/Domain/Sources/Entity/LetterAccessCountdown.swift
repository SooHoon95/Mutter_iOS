import Foundation

/// 남은 기간 계산 규칙(세 플랫폼 공통). 일수 경계는 기기 달력의 자정 기준이다.
public enum LetterAccessCountdown {
  /// 닫힘 예고를 며칠 전부터 보일지의 기본값 — 서버가 `warn_days`를 주지 않거나 권한을 못 받았을 때(계약: 없으면 2).
  public static let defaultWarnDays = 2

  /// 오늘부터 `date`까지 남은 달력 일수(같은 날 = 0, 지났으면 0).
  public static func days(until date: Date, from now: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: now)
    let end = calendar.startOfDay(for: date)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
  }
}
