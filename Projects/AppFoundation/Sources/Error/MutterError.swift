import Foundation

/// 앱 전역 에러 타입. raw 에러(Supabase/URLError 등)는 `Error.toMutterError()`로 변환해 사용한다.
/// (Mercury `MercuryError` 복제 — 브랜드 클론)
public final class MutterError: Error, Equatable {
  public let define: MutterErrorDefine

  public init(_ define: MutterErrorDefine) {
    self.define = define
  }

  /// 사용자에게 보여줄 한국어 메시지.
  public var userMessage: String {
    switch define {
    case .network:            return "네트워크 연결을 확인해 주세요."
    case .unauthorized:       return "로그인이 필요해요."
    case .notFound:           return "찾을 수 없어요."
    case .rateLimited:        return "잠시 후 다시 시도해 주세요."
    case .wrongPassword:      return "암호가 맞지 않아요."
    case .linkRevoked:        return "더 이상 열 수 없는 편지예요."
    case .linkExpired:        return "편지 링크가 만료됐어요."
    case .linkNotYetRevealed: return "아직 열 수 없는 편지예요."
    case .server(let message): return message
    case .unknown:            return "문제가 생겼어요. 다시 시도해 주세요."
    }
  }

  public static func == (lhs: MutterError, rhs: MutterError) -> Bool {
    lhs.define == rhs.define
  }
}
