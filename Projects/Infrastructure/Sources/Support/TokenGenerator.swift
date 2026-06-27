import Foundation
import Security

/// 추측불가 전달 토큰 생성(capability-links). 웹 generateToken과 동일 정책.
/// base64url(패딩 제거) — 서버가 길이·문자셋(`^[A-Za-z0-9_-]+$`, ≥22자)을 재검증한다.
enum TokenGenerator {
  /// - Parameter byteCount: 엔트로피 바이트(기본 24=192bit, 하한 16=128bit).
  static func make(byteCount: Int = 24) -> String {
    let count = max(16, byteCount)
    var bytes = [UInt8](repeating: 0, count: count)
    _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    return Data(bytes)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
