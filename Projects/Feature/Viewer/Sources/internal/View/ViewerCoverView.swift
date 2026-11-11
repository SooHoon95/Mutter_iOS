import SwiftUI

import Domain
import UIComponent

/// 로그인 전 봉투 화면 — 본문 없이 제목·보낸 사람만 보이고, "편지 열기"가 로그인으로 이어진다.
/// 로그인 뒤 같은 편지로 돌아오는 건 라우팅 레이어가 맡는다(`onOpen`).
struct ViewerCoverView: View {
  let cover: LetterCover
  /// nil이면(이미 로그인한 상태 등) 버튼을 숨긴다.
  let onOpen: (() -> Void)?

  var body: some View {
    ZStack {
      Asset.Colors.warm50.color.ignoresSafeArea()

      VStack(spacing: 24) {
        // 봉투 배지 — 열기 게이트와 같은 골드 라운드 스퀘어.
        ZStack {
          RoundedRectangle(cornerRadius: 28)
            .fill(MutterGradient.gold)
            .frame(width: 96, height: 96)
            .shadows(.shadowLow)
          MutterIcon(Asset.Images.envelope, size: 46)
            .foregroundStyle(Asset.Colors.onGold.color)
        }

        VStack(spacing: 8) {
          Text(cover.senderNickname.map(L10n.inboxTrashSender) ?? L10n.viewerArrived)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkSoft.color)

          Text(cover.title.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.viewerUntitled)
            .fonts(.titleLarge)
            .foregroundStyle(Asset.Colors.ink.color)
            .multilineTextAlignment(.center)
        }

        if let onOpen {
          MutterButton(L10n.viewerOpen, icon: Asset.Images.play, action: onOpen)
            .frame(minWidth: 200, maxWidth: 280)
        }

        Text(L10n.accessLoginHint)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkFaint.color)
      }
      .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
