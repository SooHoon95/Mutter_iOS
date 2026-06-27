import Foundation

/// 수신 딥링크 파싱 결과. 웹과 동일 경로 계약(`/l/:token`, `/connect/:token`).
public enum Deeplink: Equatable {
  case letter(token: String)
  case connect(token: String)

  /// Universal Link/커스텀 스킴 URL을 Deeplink로 해석한다. 해석 불가면 nil.
  public init?(url: URL) {
    let parts = url.pathComponents.filter { $0 != "/" }
    switch parts.first {
    case "l":
      guard let token = parts.dropFirst().first else { return nil }
      self = .letter(token: token)
    case "connect":
      guard let token = parts.dropFirst().first else { return nil }
      self = .connect(token: token)
    default:
      return nil
    }
  }
}
