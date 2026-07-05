import Foundation

import Supabase

import AppFoundation

/// Supabase/네트워크 에러를 도메인 `MutterError`로 정규화한다.
/// 서버 RPC가 raise하는 코드 문자열(웹 data 레이어와 동일 계약)을 의미 케이스로 매핑한다:
///   WRONG_PASSWORD·LINK_REVOKED·LINK_EXPIRED·*_NOT_FOUND·FORBIDDEN·NOT_YET_REVEALED:<ISO>.
enum SupabaseErrorMapper {
  static func map(_ error: Error) -> MutterError {
    if let mutter = error as? MutterError { return mutter }

    let message = extractMessage(error)

    // 세션 무효(서버 401 — JWT 만료/무효): 세션 상태 소스에 전역 신호를 쏴 온보딩으로 되돌린다.
    // 인증 데이터 호출은 모두 이 매퍼를 거치므로, 여기가 "세션이 죽었다"를 감지하는 단일 지점이다.
    // (FORBIDDEN 등 비즈니스 403은 세션 무효가 아니라 여기서 걸리지 않고 아래에서 별도 처리한다.)
    if isSessionExpired(message) {
      SessionInvalidation.notifyUnauthorized()
      return MutterError(.unauthorized)
    }

    // 예약공개: "NOT_YET_REVEALED:<ISO8601>" → 공개 시각을 담아 변환.
    if let revealAt = parseNotYetRevealed(message) {
      return MutterError(.linkNotYetRevealed(revealAt))
    }
    if message.contains("WRONG_PASSWORD") { return MutterError(.wrongPassword) }
    if message.contains("LINK_REVOKED") { return MutterError(.linkRevoked) }
    if message.contains("LINK_EXPIRED") { return MutterError(.linkExpired) }
    if message.contains("NOT_CONNECTED") { return MutterError(.notConnected) }
    if message.contains("INVITE_ALREADY_USED") { return MutterError(.inviteAlreadyUsed) }
    if message.contains("TOKEN_NOT_FOUND")
      || message.contains("LETTER_NOT_FOUND")
      || message.contains("NOT_FOUND") { return MutterError(.notFound) }
    if message.contains("FORBIDDEN") || message.contains("not_authorized") {
      return MutterError(.unauthorized)
    }
    if error is URLError { return MutterError(.network) }

    // 그 외는 AppFoundation 기본 변환(URLError→network 등)에 위임. 미매핑이면 unknown.
    return error.toMutterError() ?? MutterError(.unknown)
  }

  /// 서버가 세션을 401로 거부했는지 — JWT 만료/무효 메시지로 판정한다.
  /// (Supabase/PostgREST의 "JWT expired"·"invalid JWT" 등. 비즈니스 오류와 구분하려 JWT 신호만 신뢰해
  ///  FORBIDDEN/권한 거부(403)에는 오작동으로 로그아웃되지 않게 한다.)
  private static func isSessionExpired(_ message: String) -> Bool {
    let lower = message.lowercased()
    // JWT 만료/무효(PostgREST 401 응답 본문).
    return lower.contains("jwt expired")
      || lower.contains("jwt is expired")
      || lower.contains("token is expired")
      || lower.contains("token has expired")
      || lower.contains("invalid jwt")
      || lower.contains("jwt is invalid")
      || lower.contains("bad_jwt")
      // GoTrue 리프레시/세션 소멸(자동 갱신 실패로 세션이 죽은 경우).
      || lower.contains("refresh token")
      || lower.contains("refresh_token")
      || lower.contains("session_not_found")
      || lower.contains("session not found")
  }

  private static func extractMessage(_ error: Error) -> String {
    if let postgrest = error as? PostgrestError { return postgrest.message }
    if let auth = error as? AuthError { return auth.localizedDescription }
    return error.localizedDescription
  }

  /// "NOT_YET_REVEALED:2026-07-01T00:00:00Z" 형식에서 공개 시각을 파싱.
  private static func parseNotYetRevealed(_ message: String) -> Date? {
    guard let range = message.range(of: "NOT_YET_REVEALED:") else { return nil }
    let iso = String(message[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    return ISO8601.date(from: iso)
  }
}
