import Foundation

/// 삭제함(30일 보관) 항목 — 지운 편지의 요약. 본문은 복구 전엔 보여주지 않으므로 제목·테마만 담는다.
/// 서버 `get_my_deleted_letters`가 `purge_at = deleted_at + 30일`을 계산해 내려준다(세 플랫폼 공통 계약).
public struct DeletedLetter: Identifiable, Equatable, PurgeSchedulable {
  public let id: String
  public let title: String
  public let templateId: String
  public let deletedAt: Date
  /// 이 시각이 지나면 정리 작업이 사진까지 완전히 지운다.
  public let purgeAt: Date

  public init(id: String, title: String, templateId: String, deletedAt: Date, purgeAt: Date) {
    self.id = id
    self.title = title
    self.templateId = templateId
    self.deletedAt = deletedAt
    self.purgeAt = purgeAt
  }
}
