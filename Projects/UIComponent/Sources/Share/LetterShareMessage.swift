import Foundation

/// 전달 링크를 공유 시트로 보낼 때 링크 위에 붙는 동봉 문구.
/// 세 플랫폼(iOS·Android·웹) 공통 원문은 `marketing/plans/2026-09-16-week1-loop-spec.md` §0이 정본이다.
/// 발신자 1인칭이고 브랜드명을 넣지 않는다 — 브랜드는 링크 미리보기 카드(OG)가 맡는다.
public enum LetterShareMessage {
  /// - Parameters:
  ///   - url: 전달 링크 전체 URL. 메신저가 미리보기를 붙일 수 있게 마지막 줄에 단독으로 둔다.
  ///   - hasPassword: 암호 보호 링크면 "암호는 따로 알려줄게요." 한 줄을 덧붙인다(암호 자체는 절대 넣지 않음).
  ///   - revealAt: 예약공개 시각. `now` 이후일 때만 "…에 열려요." 한 줄을 덧붙인다.
  ///   - now: 테스트 주입용 현재 시각.
  public static func text(url: String, hasPassword: Bool, revealAt: Date?, now: Date = .now) -> String {
    var lines = [L10n.shareLetterBody]
    if hasPassword {
      lines.append(L10n.shareLetterPassword)
    }
    if let revealAt, revealAt > now {
      lines.append(L10n.shareLetterRevealAt(revealAt.formatted(date: .abbreviated, time: .shortened)))
    }
    lines.append("")
    lines.append(url)
    return lines.joined(separator: "\n")
  }
}
