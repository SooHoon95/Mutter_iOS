import SwiftUI

/// 디자인 시스템 그라데이션. 파스텔 블러시(피치→핑크→라벤더, 135° 대각선) — CTA·통계카드 등 시그니처 표면.
/// 그래디언트 스톱은 강조색 토큰(gold/goldDeep)과 **분리**한다 — 강조색은 아이콘·글자용이라 대비가
/// 필요해 더 진하고(로즈모브), 그래디언트는 밝은 파스텔이어야 하기 때문. (그래디언트 위 글자색 = `onGold`.)
public enum MutterGradient {
  public static let gold = LinearGradient(
    colors: [Asset.Colors.goldLight.color, Asset.Colors.blushPink.color, Asset.Colors.blushLavender.color],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
