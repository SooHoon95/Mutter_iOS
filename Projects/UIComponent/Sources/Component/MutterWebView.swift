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

  private let source: Source
  private let controller: MutterWebViewController?
  private let messageHandlers: [String]
  private let allowsAutoplayMedia: Bool
  private let onMessage: ((String, Any) -> Void)?
  private let onReady: (() -> Void)?
  @Binding private var isLoading: Bool

  public init(
    source: Source,
    controller: MutterWebViewController? = nil,
    messageHandlers: [String] = [],
    allowsAutoplayMedia: Bool = false,
    isLoading: Binding<Bool> = .constant(false),
    onMessage: ((String, Any) -> Void)? = nil,
    onReady: (() -> Void)? = nil
  ) {
    self.source = source
    self.controller = controller
    self.messageHandlers = messageHandlers
    self.allowsAutoplayMedia = allowsAutoplayMedia
    self._isLoading = isLoading
    self.onMessage = onMessage
    self.onReady = onReady
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
    webView.scrollView.isScrollEnabled = false
    webView.isOpaque = false
    webView.backgroundColor = .clear
    controller?.webView = webView

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

  public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let parent: MutterWebView

    init(parent: MutterWebView) {
      self.parent = parent
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
