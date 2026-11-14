import SwiftUI

import UIComponent

/// 편지 맨 끝(본문·사진 뒤) 간직 안내 — 읽기를 끊지 않도록 스크롤 마지막에 조용히 둔다.
/// ① "이 편지는 {M}월 {D}일까지 열려요" + "계속 간직하기", ② 닫힘 예고 "이 편지는 {n}일 뒤 닫혀요" + "간직하기".
/// 간직한 뒤에는 "간직한 편지예요" 한 줄만. 버튼은 한 개만 둔다 — 닫힘 예고가 있으면 그쪽에 붙인다.
struct ViewerKeepFooter: View {
  /// ① 열려 있는 기한(nil이면 ① 없음 — 영구·비로그인).
  let openUntil: Date?
  /// ② 닫히기까지 남은 일수(0 = 오늘, nil이면 ② 없음).
  let closingSoonDays: Int?
  let isKept: Bool
  let canKeep: Bool
  let isKeeping: Bool
  let errorMessage: String?
  let foreground: Color
  let onKeep: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      if isKept {
        Text(L10n.accessKept)
          .fonts(.caption)
          .foregroundStyle(foreground.opacity(0.6))
      } else {
        if let openUntil {
          line(untilText(openUntil), button: closingSoonDays == nil ? L10n.accessKeepContinue : nil)
        }
        if let days = closingSoonDays {
          line(days == 0 ? L10n.accessClosingToday : L10n.accessClosingIn(days), button: L10n.accessKeepShort)
        }
      }

      if let errorMessage {
        Text(errorMessage)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.danger.color)
      }
    }
    .multilineTextAlignment(.center)
    .padding(.top, 8)
  }

  /// 안내 한 줄 + (간직할 수 있으면) 글자 버튼.
  @ViewBuilder
  private func line(_ text: String, button: String?) -> some View {
    VStack(spacing: 4) {
      Text(text)
        .fonts(.caption)
        .foregroundStyle(foreground.opacity(0.6))
      if let button, canKeep {
        Button(action: onKeep) {
          if isKeeping {
            ProgressView().tint(Asset.Colors.gold.color)
          } else {
            Text(button).fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
        .disabled(isKeeping)
      }
    }
  }

  /// "이 편지는 {M}월 {D}일까지 열려요" — 기기 달력 기준 날짜.
  private func untilText(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.month, .day], from: date)
    return L10n.accessOpenUntil(parts.month ?? 0, parts.day ?? 0)
  }
}
