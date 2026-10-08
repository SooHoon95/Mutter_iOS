import SwiftUI
import WebKit

/// WKWebView를 명령형으로 제어하기 위한 컨트롤러.
/// AudioSync의 SoundCloud 소스가 이 컨트롤러로 위젯 JS(play/pause/seek/volume)를 호출한다.
public final class MutterWebViewController {
  fileprivate weak var webView: WKWebView?

  public init() {}

  /// 임의의 JS를 실행한다(결과 무시).
  public func evaluateJavaScript(_ js: String) {
    webView?.evaluateJavaScript(js, completionHandler: nil)
  }

  /// JS를 실행하고 결과를 비동기로 받는다.
  public func evaluateJavaScript(_ js: String) async -> Any? {
    guard let webView else { return nil }
    return try? await webView.evaluateJavaScript(js)
  }
}

/// 제네릭 WKWebView 래퍼(Mercury `MercuryWebView` 확장 — JS 양방향 브리지 추가).
/// 도메인 비종속: SoundCloud 등 구체 위젯 로직은 호출부(AudioSync)가 JS로 주입한다.
public struct MutterWebView: UIViewRepresentable {
  public enum Source {
    case url(URL)
    case html(String, baseURL: URL?)
  }

  /// 페이지 이동 요청 처리 방식. 인앱 브라우징에서 허용 도메인 밖 링크를 걸러낼 때 쓴다.
  public enum NavigationPolicy {
    case allow
    /// 앱 웹뷰에서는 막고 시스템(Safari)으로 연다.
    case openExternally
    case cancel
  }

  private let source: Source
  private let controller: MutterWebViewController?
  private let messageHandlers: [String]
  private let allowsAutoplayMedia: Bool
  private let onMessage: ((String, Any) -> Void)?
  private let onReady: (() -> Void)?
  private let isBrowsable: Bool
  private let onURLChange: ((URL?) -> Void)?
  private let navigationPolicy: ((URL) -> NavigationPolicy)?
  @Binding private var isLoading: Bool

  public init(
    source: Source,
    controller: MutterWebViewController? = nil,
    messageHandlers: [String] = [],
    allowsAutoplayMedia: Bool = false,
    isLoading: Binding<Bool> = .constant(false),
    onMessage: ((String, Any) -> Void)? = nil,
    onReady: (() -> Void)? = nil,
    isBrowsable: Bool = false,
    onURLChange: ((URL?) -> Void)? = nil,
    navigationPolicy: ((URL) -> NavigationPolicy)? = nil
  ) {
    self.source = source
    self.controller = controller
    self.messageHandlers = messageHandlers
    self.allowsAutoplayMedia = allowsAutoplayMedia
    self._isLoading = isLoading
    self.onMessage = onMessage
    self.onReady = onReady
    self.isBrowsable = isBrowsable
    self.onURLChange = onURLChange
    self.navigationPolicy = navigationPolicy
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  public func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    if allowsAutoplayMedia {
      configuration.mediaTypesRequiringUserActionForPlayback = []
    }

    // JS → 네이티브 메시지 핸들러 등록. 약한 프록시로 retain cycle을 끊는다.
    let userContent = configuration.userContentController
    for name in messageHandlers {
      userContent.add(WeakScriptMessageHandler(context.coordinator), name: name)
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    if isBrowsable {
      webView.uiDelegate = context.coordinator
    }
    // 숨김 위젯 용도는 스크롤을 막고, 사용자가 직접 탐색하는 브라우저 용도만 스크롤과 스와이프 뒤로가기를 켠다.
    webView.scrollView.isScrollEnabled = isBrowsable
    webView.allowsBackForwardNavigationGestures = isBrowsable
    webView.isOpaque = false
    webView.backgroundColor = .clear
    controller?.webView = webView
    context.coordinator.observeURL(of: webView)

    switch source {
    case .url(let url):
      webView.load(URLRequest(url: url))
    case .html(let html, let baseURL):
      webView.loadHTMLString(html, baseURL: baseURL)
    }
    return webView
  }

  public func updateUIView(_ uiView: WKWebView, context: Context) {}

  public static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
    // 등록한 메시지 핸들러를 해제해 누수를 막는다.
    uiView.configuration.userContentController.removeAllScriptMessageHandlers()
  }

  public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let parent: MutterWebView
    private var urlObservation: NSKeyValueObservation?

    init(parent: MutterWebView) {
      self.parent = parent
    }

    /// SPA(pushState) 이동은 navigation delegate를 거치지 않아 `url` KVO로만 잡힌다.
    func observeURL(of webView: WKWebView) {
      guard let onURLChange = parent.onURLChange else { return }
      urlObservation = webView.observe(\.url, options: [.initial, .new]) { webView, _ in
        let url = webView.url
        // `.initial`이 makeUIView 도중에 불리므로, SwiftUI 갱신 중 상태 변경을 피하려고 다음 런루프로 미룬다.
        DispatchQueue.main.async { onURLChange(url) }
      }
    }

    public func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
      guard let policy = parent.navigationPolicy,
            let url = navigationAction.request.url,
            navigationAction.targetFrame?.isMainFrame ?? true else {
        decisionHandler(.allow)
        return
      }
      switch policy(url) {
      case .allow:
        decisionHandler(.allow)
      case .openExternally:
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
      case .cancel:
        decisionHandler(.cancel)
      }
    }

    /// `target=_blank` 링크는 새 창 대신 현재 웹뷰에서 연다(새 창을 띄울 곳이 없다).
    public func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      if navigationAction.targetFrame == nil {
        webView.load(navigationAction.request)
      }
      return nil
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      parent.isLoading = true
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.isLoading = false
      parent.onReady?()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.isLoading = false
    }

    public func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      parent.onMessage?(message.name, message.body)
    }
  }
}

/// WKScriptMessageHandler를 약하게 보유하는 프록시.
/// (userContentController가 핸들러를 강하게 잡아 생기는 retain cycle 방지.)
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  private weak var target: WKScriptMessageHandler?

  init(_ target: WKScriptMessageHandler) {
    self.target = target
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    target?.userContentController(userContentController, didReceive: message)
  }
}
