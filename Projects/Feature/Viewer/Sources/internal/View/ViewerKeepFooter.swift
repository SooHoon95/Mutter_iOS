import SwiftUI

import UIComponent

/// 편지 맨 끝(본문·사진 뒤) 간직 안내 — 읽기를 끊지 않도록 스크롤 마지막에 조용히 둔다.
/// ① "이 편지는 {M}월 {D}일까지 열려요" + "계속 간직하기", ② 닫힘 예고 "이 편지는 {n}일 뒤 닫혀요" + "간직하기".
/// 간직한 뒤에는 "간직한 편지예요" 한 줄만. 버튼은 한 개만 둔다 — 닫힘 예고가 있으면 그쪽에 붙인다.
///
/// 편지권이 있으면 글자 버튼을 누른 자리에서 한 번 더 묻는다(팝업 없이 같은 줄이 확인으로 바뀐다) —
/// 작은 글자 버튼 한 번에 편지권이 쓰이지 않게. 편지권이 없으면 누르는 즉시 결제 안내 시트가 뜬다.
struct ViewerKeepFooter: View {
  /// ① 열려 있는 기한(nil이면 ① 없음 — 영구·비로그인).
  let openUntil: Date?
  /// ② 닫히기까지 남은 일수(0 = 오늘, nil이면 ② 없음).
  let closingSoonDays: Int?
  let isKept: Bool
  let canKeep: Bool
  /// 지금 쓸 편지권이 있는지 — 있으면 같은 자리에서 확인을 받고, 없으면 바로 `onKeep`(결제 안내).
  let hasTicket: Bool
  let isKeeping: Bool
  let errorMessage: String?
  let foreground: Color
  let onKeep: () -> Void

  @State private var isConfirming = false

  var body: some View {
    VStack(spacing: 8) {
      if isKept {
        Text(L10n.accessKept)
          .fonts(.caption)
          .foregroundStyle(foreground.opacity(0.6))
      } else if isConfirming {
        confirmation
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
        Button {
          if hasTicket {
            withAnimation(.easeInOut(duration: 0.15)) { isConfirming = true }
          } else {
            onKeep()
          }
        } label: {
          Text(button).fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
        }
      }
    }
  }

  /// 같은 자리의 확인 — "편지권 1장을 사용해요…" + 취소 / 간직하기.
  private var confirmation: some View {
    VStack(spacing: 8) {
      Text(L10n.accessKeepNotice)
        .fonts(.caption)
        .foregroundStyle(foreground.opacity(0.6))
      HStack(spacing: 20) {
        Button {
          withAnimation(.easeInOut(duration: 0.15)) { isConfirming = false }
        } label: {
          Text(L10n.commonCancel).fonts(.caption).foregroundStyle(foreground.opacity(0.6))
        }
        .disabled(isKeeping)

        Button(action: onKeep) {
          if isKeeping {
            ProgressView().tint(Asset.Colors.gold.color)
          } else {
            Text(L10n.accessKeepShort).fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
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
