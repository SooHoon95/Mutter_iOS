import Foundation

import AppFoundation

/// 수신 딥링크(AppFoundation `Deeplink`)를 화면 라우트로 변환한다.
/// `/l/:token`→Viewer, `/connect/:token`→Connect. (웹과 동일 경로 계약)
public enum DeeplinkRouter {
  public static func route(for deeplink: Deeplink) -> FeatureRoute {
    switch deeplink {
    case .letter(let token):
      return .viewer(.token(token, password: nil))
    case .connect(let token):
      return .connect(.invite(token: token))
    }
  }

  /// URL을 직접 라우트로(해석 불가면 nil).
  public static func route(for url: URL) -> FeatureRoute? {
    Deeplink(url: url).map(route(for:))
  }
}
