import Foundation

/// 연결된 상대(독점 1:1 연결).
public struct Connection: Identifiable, Equatable {
  public let userId: String
  public let nickname: String?
  public let connectedAt: Date

  public var id: String { userId }

  public init(userId: String, nickname: String?, connectedAt: Date) {
    self.userId = userId
    self.nickname = nickname
    self.connectedAt = connectedAt
  }
}

/// 연결 초대 미리보기 — 초대 링크를 열었을 때의 상태(수락 가능 여부 판단).
public struct ConnectInvite: Equatable {
  public let inviterId: String
  public let inviterNickname: String?
  /// 내가 보낸 초대를 내가 연 경우.
  public let isSelf: Bool
  /// 이미 둘이 연결된 경우.
  public let alreadyConnected: Bool
  /// 내가 이미 다른 사람과 연결된 경우(독점 1:1 — 수락 불가).
  public let viewerHasConnection: Bool
  /// 초대자가 이미 다른 사람과 연결된 경우.
  public let inviterHasConnection: Bool

  public init(
    inviterId: String,
    inviterNickname: String?,
    isSelf: Bool,
    alreadyConnected: Bool,
    viewerHasConnection: Bool,
    inviterHasConnection: Bool
  ) {
    self.inviterId = inviterId
    self.inviterNickname = inviterNickname
    self.isSelf = isSelf
    self.alreadyConnected = alreadyConnected
    self.viewerHasConnection = viewerHasConnection
    self.inviterHasConnection = inviterHasConnection
  }

  /// 둘 다 미연결일 때만 수락 가능(독점 1:1 불변식).
  public var canAccept: Bool {
    !isSelf && !alreadyConnected && !viewerHasConnection && !inviterHasConnection
  }
}

/// 주고받은 상대(스레드 목록의 한 항목).
public struct Counterpart: Identifiable, Equatable {
  public let userId: String
  public let nickname: String?
  public let exchangeCount: Int

  public var id: String { userId }

  public init(userId: String, nickname: String?, exchangeCount: Int) {
    self.userId = userId
    self.nickname = nickname
    self.exchangeCount = exchangeCount
  }
}
