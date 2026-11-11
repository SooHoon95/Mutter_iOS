import Foundation

/// 편지 봉투(get_letter_cover) — 본문 없이 로그인 전 화면·잠김 화면에 쓰는 겉면 정보.
/// `isSealed`면 나머지는 전부 nil이다(토큰 없음·회수·만료·암호·예약 공개 전·삭제함 — 이유 구분 불가).
public struct LetterCover: Equatable {
  public let isSealed: Bool
  public let templateId: String?
  public let title: String?
  public let senderNickname: String?
  public let accessType: LetterAccessType?
  public let accessUntil: Date?
  public let deleteAt: Date?
  /// "이 편지는 로그인이 필요한가" — 호출자의 로그인 여부와 무관하다.
  public let loginRequired: Bool

  public init(
    isSealed: Bool,
    templateId: String? = nil,
    title: String? = nil,
    senderNickname: String? = nil,
    accessType: LetterAccessType? = nil,
    accessUntil: Date? = nil,
    deleteAt: Date? = nil,
    loginRequired: Bool = false
  ) {
    self.isSealed = isSealed
    self.templateId = templateId
    self.title = title
    self.senderNickname = senderNickname
    self.accessType = accessType
    self.accessUntil = accessUntil
    self.deleteAt = deleteAt
    self.loginRequired = loginRequired
  }

  /// 봉투 정보가 없는 경우(조회 실패·sealed)의 빈 봉투.
  public static let sealed = LetterCover(isSealed: true)
}
