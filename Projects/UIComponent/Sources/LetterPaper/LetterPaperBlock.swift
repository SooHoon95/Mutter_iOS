import Foundation

/// 편지지에 그릴 블록. Domain을 모르는 UIComponent용 표현이라 Feature가 도메인 블록을 이 형태로 바꿔 넘긴다.
public enum LetterPaperBlock {
  case text(String)
  /// 사진 — `cacheKey`는 Storage 경로(서명 URL은 매번 달라 캐시 키로 쓸 수 없다).
  /// `url`이 nil이면(발급 전·실패) 비율을 지킨 플레이스홀더로 자리를 잡는다.
  case photo(id: String, url: URL?, cacheKey: String?, aspectRatio: CGFloat)
}
