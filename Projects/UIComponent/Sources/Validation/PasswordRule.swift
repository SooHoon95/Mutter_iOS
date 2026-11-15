import Foundation

/// 로그인 비밀번호 입력 규칙 — 로그인 직후 설정 단계와 프로필 설정 시트가 같이 쓴다.
/// 서버(Supabase) 최소 길이 6과 웹 가입 규칙에 맞춘다(docs/specs/2026-11-14-login-password.md).
public enum PasswordRule {
  public static let minLength = 6

  /// 저장해도 되면 nil, 아니면 사용자에게 보일 문구.
  public static func validate(_ password: String, confirm: String) -> String? {
    if password.count < minLength { return L10n.authPasswordTooShort }
    if password != confirm { return L10n.authPasswordMismatch }
    return nil
  }
}
