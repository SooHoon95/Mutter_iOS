import Foundation

/// 받은 편지 삭제함 항목 — 받은 편지함에서 지운 편지(30일 보관). 보낸 사람이 지운 편지는 서버가 빼고 내려준다.
public struct DeletedInboxItem: Identifiable, Equatable, PurgeSchedulable {
  public let letterId: String
  public let token: String
  public let title: String
  public let senderId: String?
  /// 보낸 사람 닉네임. nil이면 화면에서 "알 수 없음".
  public let senderNickname: String?
  public let deletedAt: Date
  public let purgeAt: Date

  public var id: String { letterId }

  public init(
    letterId: String,
    token: String,
    title: String,
    senderId: String?,
    senderNickname: String?,
    deletedAt: Date,
    purgeAt: Date
  ) {
    self.letterId = letterId
    self.token = token
    self.title = title
    self.senderId = senderId
    self.senderNickname = senderNickname
    self.deletedAt = deletedAt
    self.purgeAt = purgeAt
  }
}
