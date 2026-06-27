import Foundation

import Pulse

/// Pulse 네트워크 로깅 토글.
/// `enableAutomaticRegistration`은 URLSession 생성을 후킹해 모든 트래픽을 Pulse 스토어에 기록한다
/// (Supabase가 내부에서 만드는 세션도 포함). `static let`으로 1회만 등록되도록 보장한다.
public enum NetworkLogging {
  private static let registered: Void = {
    URLSessionProxyDelegate.enableAutomaticRegistration()
  }()

  /// 네트워크 로깅을 켠다(중복 호출해도 1회만 등록).
  public static func enable() {
    _ = registered
  }
}
