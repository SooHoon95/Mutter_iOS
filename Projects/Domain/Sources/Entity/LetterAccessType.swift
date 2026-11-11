import Foundation

/// 편지 접근 상태 분류(서버 `state`). 계약: `docs/specs/permanent-letter-contract.md` "상태".
public enum LetterAccessType: String, Equatable {
  /// 기간 제한 없음(기존 편지·영구 편지권·관리자).
  case permanent
  /// 무료 기간 안. 아직 아무도 안 열었으면 시각이 둘 다 nil.
  case open
  /// 무료 기간이 끝남. 편지권을 붙이면 다시 열린다.
  case locked
  /// 유예도 끝남. 되살릴 수 없다.
  case gone
}
