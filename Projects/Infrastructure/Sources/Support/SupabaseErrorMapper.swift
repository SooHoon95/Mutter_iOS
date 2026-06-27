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

    // 예약공개: "NOT_YET_REVEALED:<ISO8601>" → 공개 시각을 담아 변환.
    if let revealAt = parseNotYetRevealed(message) {
      return MutterError(.linkNotYetRevealed(revealAt))
    }
    if message.contains("WRONG_PASSWORD") { return MutterError(.wrongPassword) }
    if message.contains("LINK_REVOKED") { return MutterError(.linkRevoked) }
    if message.contains("LINK_EXPIRED") { return MutterError(.linkExpired) }
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
