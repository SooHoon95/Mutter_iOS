import SwiftUI

import Domain
import UIComponent

/// 앱 안에서 soundcloud.com을 둘러보다가 트랙 페이지에서 "이 곡 넣기"로 바로 고르는 시트.
/// 정책 준수(Apple 5.2.2/5.2.3, SoundCloud 약관 스크래핑·고지 변경 금지): 페이지에 JS/CSS를 주입하지 않고,
/// 오디오도 건드리지 않으며, 지금 보고 있는 URL 하나만 읽는다. 제목·작성자는 기존 oEmbed 검증이 채운다.
struct SoundCloudPickerSheet: View {
  let onPick: (URL) -> Void
  let onClose: () -> Void

  @State private var trackURL: URL?
  @State private var isLoading = false

  /// discover는 플레이리스트 위주라 곡을 바로 고르기 어렵다 — 검색 화면에서 시작한다.
  private static let startURL = URL(string: "https://m.soundcloud.com/search")!

  var body: some View {
    VStack(spacing: 0) {
      MutterNavigationBar(
        Asset.Colors.ivory.color,
        L10n.composeSoundcloudPickerTitle,
        titleFont: .bodyMediumBold,
        leftButtons: { MutterBackButton(action: onClose) }
      )

      MutterWebView(
        source: .url(Self.startURL),
        isLoading: $isLoading,
        isBrowsable: true,
        onURLChange: { trackURL = SoundCloudTrackPage.trackURL(from: $0) },
        navigationPolicy: Self.policy
      )
      .overlay(alignment: .top) {
        if isLoading {
          ProgressView().padding(.top, 12)
        }
      }

      VStack(spacing: 8) {
        Text(trackURL == nil ? L10n.composeSoundcloudPickerHint : L10n.composeSoundcloudPickerReady)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkFaint.color)
        MutterButton(L10n.composeSoundcloudPick, isEnabled: trackURL != nil) {
          if let trackURL { onPick(trackURL) }
        }
      }
      .padding(16)
      .background(Asset.Colors.ivory.color)
    }
    .background(Asset.Colors.ivory.color.ignoresSafeArea())
  }

  /// SoundCloud 안에서는 자유롭게 탐색하고, 바깥 웹 링크는 Safari로 넘긴다.
  /// 앱 스킴·스토어 유도(soundcloud://, itms-apps:// 등)는 시트를 벗어나지 않도록 막는다.
  private static func policy(_ url: URL) -> MutterWebView.NavigationPolicy {
    let scheme = url.scheme?.lowercased()
    guard scheme == "https" || scheme == "http" else {
      return scheme == "about" ? .allow : .cancel
    }
    let host = url.host?.lowercased() ?? ""
    let isSoundCloud = host == "soundcloud.com" || host.hasSuffix(".soundcloud.com")
      || host.hasSuffix(".sndcdn.com")
    return isSoundCloud ? .allow : .openExternally
  }
}
