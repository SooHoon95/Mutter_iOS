import SwiftUI

import Domain
import UIComponent

/// 잠김 화면 — 무료 기간이 끝난 편지. 본문 대신 제목·보낸 사람·다시 열 수 있는 기한을 보이고,
/// 편지권 UI가 켜진 로그인 사용자에게만 "편지권으로 간직하기"를 준다.
struct ViewerLockedView: View {
  let cover: LetterCover
  /// 삭제 예정 시각 — 이날까지 편지권을 붙이면 다시 열린다.
  let deleteAt: Date
  let canKeep: Bool
  let isKeeping: Bool
  let errorMessage: String?
  let onKeep: () -> Void

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 20) {
        ZStack {
          Circle()
            .fill(Asset.Colors.goldSoft.color)
            .frame(width: 72, height: 72)
          MutterIcon(Asset.Images.lock, size: 32)
            .foregroundStyle(Asset.Colors.gold.color)
        }

        VStack(spacing: 8) {
          Text(L10n.accessLockedTitle)
            .fonts(.title)
            .foregroundStyle(Asset.Colors.ink.color)
            .multilineTextAlignment(.center)

          if let title = cover.title, !title.isEmpty {
            Text(title)
              .fonts(.bodyMediumBold)
              .foregroundStyle(Asset.Colors.ink.color)
              .multilineTextAlignment(.center)
          }
          if let sender = cover.senderNickname {
            Text(L10n.inboxTrashSender(sender))
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.inkSoft.color)
          }

          Text(untilText)
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkSoft.color)
            .multilineTextAlignment(.center)
        }

        if canKeep {
          MutterButton(L10n.accessKeep, isLoading: isKeeping, action: onKeep)
            .frame(minWidth: 200, maxWidth: 280)
        }

        if let errorMessage {
          Text(errorMessage)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.danger.color)
        }
      }
      .padding(32)
      .frame(maxWidth: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// "{M}월 {D}일까지 다시 열 수 있어요." — 기기 달력 기준 날짜.
  private var untilText: String {
    let parts = Calendar.current.dateComponents([.month, .day], from: deleteAt)
    return L10n.accessLockedUntil(parts.month ?? 0, parts.day ?? 0)
  }
}
