import CoreGraphics

/// Mutter 모서리 반경 토큰(웹 `tokens.css` --radius-* 이식).
/// 컴포넌트는 cornerRadius 리터럴 대신 이 값을 참조한다.
public enum MutterRadius {
  /// 2px — 미세
  public static let xs: CGFloat = 2
  /// 4px — 입력/작은 카드
  public static let sm: CGFloat = 4
  /// 8px — 기본 카드
  public static let md: CGFloat = 8
  /// 12px — 큰 카드/버튼
  public static let lg: CGFloat = 12
  /// 16px — 시트/모달
  public static let xl: CGFloat = 16
  /// 완전 둥글게(pill/캡슐)
  public static let full: CGFloat = 9999
}
