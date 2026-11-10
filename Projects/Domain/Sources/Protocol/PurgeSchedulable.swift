import Foundation

/// 삭제함 항목 공통 — 보관 기한(`purgeAt`)이 지나면 정리 작업이 완전히 지운다.
/// 내 편지 삭제함·받은 편지 삭제함이 같은 남은 기간 규칙(스펙 3.2)을 쓰도록 한 곳에 둔다.
public protocol PurgeSchedulable {
  var purgeAt: Date { get }
}

public extension PurgeSchedulable {
  /// 완전 삭제까지 남은 일수(올림). 0 이하면 오늘 정리 대상이다.
  /// 올림이라 남은 시간이 조금이라도 있으면 최소 1일로 표시된다 — 사용자가 "벌써 지워졌나" 오해하지 않게.
  func remainingDays(now: Date = Date()) -> Int {
    let seconds = purgeAt.timeIntervalSince(now)
    guard seconds > 0 else { return 0 }
    return Int((seconds / 86_400).rounded(.up))
  }
}
