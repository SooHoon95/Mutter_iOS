import Foundation

/// 앱 전역 에러의 의미 분류. 사용자 메시지·복구 분기는 이 케이스로 한다.
public enum MutterErrorDefine: Equatable {
  case network
  case unauthorized
  case notFound
  case rateLimited
  case wrongPassword
  case linkRevoked
  case linkExpired
  case linkNotYetRevealed(Date)
  /// 연결되지 않은 상대에게 편지를 보내려 할 때 (EC-3.2)
  case notConnected
  /// 이미 사용된 초대 링크 수락 시도 (EC-2.2)
  case inviteAlreadyUsed
  /// 로그인해야 열리는 편지를 익명으로 열려 할 때(LOGIN_REQUIRED) — 봉투 화면으로.
  case loginRequired
  /// 무료 기간이 끝난 편지(LETTER_LOCKED:<ISO>). 시각 = 삭제 예정 시각.
  case letterLocked(Date)
  /// 유예까지 끝나 되살릴 수 없는 편지(LETTER_GONE).
  case letterGone
  /// 편지권 잔액 부족(NO_TICKET).
  case noTicket
  /// 편지권 구매를 아직 쓸 수 없음(StoreKit 연동 전).
  case purchaseUnavailable
  /// 비밀번호 로그인 실패 — 이메일·비밀번호 불일치(Supabase `invalid_credentials`).
  /// 코드로 가입한 계정은 직접 정한 비밀번호가 없어 항상 여기로 온다.
  case invalidCredentials
  /// 이메일 인증 전 계정의 비밀번호 로그인(`email_not_confirmed`).
  case emailNotConfirmed
  /// 비밀번호 설정 — 6자 미만(`weak_password`).
  case weakPassword
  /// 비밀번호 설정 — 지금 비밀번호와 같음(`same_password`).
  case samePassword
  /// 비밀번호 설정 — 최근 로그인이 필요함(`reauthentication_needed`).
  case reauthenticationNeeded
  /// 코드 메일 발송 한도 초과(`over_email_send_rate_limit`) — 기본 메일 서버의 시간당 제한.
  case emailSendLimited
  case server(String)
  case unknown
}
