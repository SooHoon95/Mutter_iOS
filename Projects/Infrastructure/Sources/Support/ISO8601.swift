import Foundation

/// ISO8601 날짜 파싱/직렬화(Supabase `timestamptz` ↔ `Date`).
/// 소수 초(.SSS) 유무를 모두 허용한다.
enum ISO8601 {
  private static let withFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let plain: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// ISO 문자열 → Date(파싱 실패 시 nil).
  static func date(from string: String) -> Date? {
    withFraction.date(from: string) ?? plain.date(from: string)
  }

  /// Date → ISO 문자열(서버 전송용).
  static func string(from date: Date) -> String {
    plain.string(from: date)
  }
}
