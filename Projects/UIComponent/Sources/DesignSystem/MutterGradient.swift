import SwiftUI

/// 디자인 시스템 그라데이션. 골드 포일(웹 `--gold-gradient`, 135° 대각선) — CTA·통계카드 등 시그니처 표면.
public enum MutterGradient {
  public static let gold = LinearGradient(
    colors: [Asset.Colors.goldLight.color, Asset.Colors.gold.color, Asset.Colors.goldDeep.color],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
