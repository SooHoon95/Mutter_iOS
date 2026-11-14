import Foundation

/// 편지 한 통의 접근 상태(get_letter_access_states 한 행).
/// 목록 RPC의 반환 형태를 건드리지 않고 클라이언트가 letterId로 목록에 합친다.
public struct LetterAccessState: Equatable {
  public let letterId: String
  public let type: LetterAccessType
  /// open: 잠기는 시각(아직 아무도 안 열었으면 nil) / locked: 잠긴 시각.
  public let accessUntil: Date?
  /// 삭제 예정 시각(open이고 아직 안 열렸으면 nil).
  public let deleteAt: Date?

  public init(letterId: String, type: LetterAccessType, accessUntil: Date?, deleteAt: Date?) {
    self.letterId = letterId
    self.type = type
    self.accessUntil = accessUntil
    self.deleteAt = deleteAt
  }

  /// 목록에 붙일 상태 표시. `showsPermanent`가 false면 영구 편지에는 아무것도 붙이지 않는다 —
  /// 편지권 UI가 꺼진 계정에서 기존 편지(전부 permanent) 목록이 지금과 똑같이 보이게 하기 위해서다.
  public func badge(showsPermanent: Bool, now: Date = Date(), calendar: Calendar = .current) -> LetterAccessBadgeType? {
    switch type {
    case .permanent:
      return showsPermanent ? .permanent : nil
    case .open:
      // 아직 아무도 안 열어 시계가 시작되지 않은 편지는 남은 일수가 없다.
      guard let accessUntil else { return nil }
      // 당일 닫히는 편지도 "0일 남음" 대신 1일로 보인다(목록 문구엔 "오늘"이 없다).
      return .daysLeft(max(1, LetterAccessCountdown.days(until: accessUntil, from: now, calendar: calendar)))
    case .locked, .gone:
      return .locked
    }
  }
}
