import Foundation

/// 수신 딥링크 파싱 결과. 웹과 동일 경로 계약(`/l/:token`, `/connect/:token`).
public enum Deeplink: Equatable {
  case letter(token: String)
  case connect(token: String)

  /// Universal Link(`https://…/l/:token`)와 커스텀 스킴(`mutter://l/:token`)을 Deeplink로 해석한다.
  /// 스킴 화이트리스트로 미지원 스킴(`ftp://` 등)과 OAuth 콜백(`kakao…://`, 역방향 클라이언트 ID)을 배제한다.
  /// 해석 불가면 nil.
  public init?(url: URL) {
    // 스킴별로 키워드(l/connect)와 토큰을 뽑는다.
    let keyword: String?
    let token: String?

    switch url.scheme?.lowercased() {
    case "mutter":
      // 커스텀 스킴: host가 키워드, 첫 path 컴포넌트가 토큰(`mutter://connect/<token>`).
      guard let host = url.host, !host.isEmpty else { return nil }
      keyword = host
      token = url.pathComponents.first { $0 != "/" }
    case "https", "http":
      // Universal Link: 경로 첫 두 컴포넌트가 키워드·토큰(`https://…/connect/<token>`). 기존 동작 보존.
      let parts = url.pathComponents.filter { $0 != "/" }
      keyword = parts.first
      token = parts.dropFirst().first
    default:
      // ftp:// 등 미지원 스킴, OAuth 콜백 스킴(kakao…://, com.googleusercontent…://).
      return nil
    }

    guard let token, !token.isEmpty else { return nil }
    switch keyword {
    case "l":
      self = .letter(token: token)
    case "connect":
      self = .connect(token: token)
    default:
      return nil
    }
  }
}
