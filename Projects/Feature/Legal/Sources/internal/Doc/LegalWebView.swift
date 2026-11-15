import SwiftUI

import UIComponent

/// 웹에 올린 정식 문서(개인정보처리방침 등)를 앱 안에서 보여 주는 화면.
/// 문서가 있는 사이트 안에서는 그대로 이동하고, 다른 사이트 링크는 Safari로 넘긴다.
struct LegalWebView: View {
  let title: String
  let url: URL
  private let onBack: () -> Void

  @State private var isLoading = false

  init(title: String, url: URL, onBack: @escaping () -> Void) {
    self.title = title
    self.url = url
    self.onBack = onBack
  }

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          title,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        MutterWebView(
          source: .url(url),
          isLoading: $isLoading,
          isBrowsable: true,
          navigationPolicy: policy
        )
        .overlay(alignment: .top) {
          if isLoading {
            ProgressView().padding(.top, 12)
          }
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private func policy(_ target: URL) -> MutterWebView.NavigationPolicy {
    let scheme = target.scheme?.lowercased()
    guard scheme == "https" || scheme == "http" else {
      return scheme == "about" ? .allow : .openExternally
    }
    return target.host?.lowercased() == url.host?.lowercased() ? .allow : .openExternally
  }
}
