import Foundation

/// GA4로 보내는 이벤트. 이름·파라미터는 3플랫폼 계약(docs/specs/2026-11-16-analytics.md)과 같다.
/// 개인정보(이메일·닉네임·편지 내용·토큰·사용자 ID)는 케이스에 담지 않는다.
public enum AnalyticsEvent: Equatable {
  /// 로그인 성공(가입 포함). method: password·code·apple·google·kakao.
  case login(method: String)
  /// 이메일 회원가입 코드 인증 성공.
  case signUpEmail
  /// 가입 후 닉네임 저장 성공 — 가입 방법과 상관없는 가입 완료 지점.
  case onboardComplete
  /// 새 편지 첫 저장 성공.
  case letterCreate(reply: Bool)
  /// 전달 링크 발급 성공.
  case linkIssue(permanent: Bool, hasPassword: Bool)
  /// 연결 상대에게 직접 발송 성공.
  case letterSend(permanent: Bool, reply: Bool)
  /// 편지 본문 표시 성공. source: link(받은 링크) · my_letter(내 편지 미리보기).
  case letterOpen(source: String)
  /// 받은 사람이 편지권으로 간직 성공.
  case letterKeep
  /// 보낸 편지를 나중에 영구로 만들기 성공.
  case letterMakePermanent
  /// 편지권 구매 성공(서버 반영 후).
  case ticketPurchase(productId: String)
  /// 연결 초대 링크 만들기 성공.
  case inviteCreate

  public var name: String {
    switch self {
    case .login: return "login"
    case .signUpEmail: return "sign_up"
    case .onboardComplete: return "onboard_complete"
    case .letterCreate: return "letter_create"
    case .linkIssue: return "link_issue"
    case .letterSend: return "letter_send"
    case .letterOpen: return "letter_open"
    case .letterKeep: return "letter_keep"
    case .letterMakePermanent: return "letter_make_permanent"
    case .ticketPurchase: return "ticket_purchase"
    case .inviteCreate: return "invite_create"
    }
  }

  /// bool은 플랫폼 간 같은 값이 되도록 "true"/"false" 문자열로 보낸다.
  public var parameters: [String: String] {
    switch self {
    case .login(let method): return ["method": method]
    case .signUpEmail: return ["method": "email"]
    case .letterCreate(let reply): return ["reply": String(reply)]
    case .linkIssue(let permanent, let hasPassword):
      return ["permanent": String(permanent), "has_password": String(hasPassword)]
    case .letterSend(let permanent, let reply):
      return ["permanent": String(permanent), "reply": String(reply)]
    case .letterOpen(let source): return ["source": source]
    case .ticketPurchase(let productId): return ["product_id": productId]
    case .onboardComplete, .letterKeep, .letterMakePermanent, .inviteCreate: return [:]
    }
  }
}
