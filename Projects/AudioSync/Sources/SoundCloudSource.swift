import SwiftUI
import os

import AppFoundation
import UIComponent

/// SoundCloud 트랙 재생 — 공식 Widget API를 WKWebView에서 구동한다.
/// 스트림 URL을 rip/proxy/캐시하지 않고, canonical 트랙 URL을 위젯에 넘겨 **공식 임베드**로만 재생한다
/// (면책 유지 — license-compliance/music-sync 스킬 참조).
///
/// ## 동작 원리 (네이티브 ↔ JS 브리지)
/// 1. `attachmentView`가 숨김 WKWebView를 뷰 계층에 올린다(보이지 않지만 JS 실행에 필요).
/// 2. 웹뷰가 SC `api.js`를 로드하고 `SC.Widget(iframe)`을 만든다.
/// 3. 위젯 READY/FINISH 이벤트 → `window.webkit.messageHandlers.sc.postMessage(...)`로 네이티브에 통지.
/// 4. 네이티브 → JS 제어: `controller.evaluateJavaScript("window.scPlay()")` 등으로 play/pause/seek/volume.
///
/// `load()`는 READY 메시지를 받을 때까지 대기한다(미수신 시 타임아웃 → 폴백 유도).
/// ⚠️ R1: 실기기에서 SC 위젯 자동재생/제어 신뢰성은 출시 전 디바이스 스파이크로 검증한다.
@MainActor
public final class SoundCloudSource: TrackSource {
  private let trackURL: URL
  private let startMs: Int

  /// 네이티브 → JS 명령 채널(UIComponent WKWebView 제어기).
  private let controller = MutterWebViewController()
  private var readyContinuation: CheckedContinuation<Void, Error>?
  private var isReady = false
  /// 재생 의도. READY 전에 play()가 와도 기억했다가 위젯 준비 시 자동 재생한다(레이스 방지).
  private var wantsPlay = false
  private static let log = Logger(subsystem: "com.efreedom.mutter", category: "audio")

  public var onFinish: (() -> Void)?

  public init(trackURL: URL, startMs: Int = 0) {
    self.trackURL = trackURL
    self.startMs = startMs
  }

  public func load() async throws {
    Self.log.debug("SC load 시작 url=\(self.trackURL.absoluteString, privacy: .public)")
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.readyContinuation = continuation
      // 타임아웃: READY가 안 오면 실패시켜 무음0 폴백을 유도한다.
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(10))
        guard !self.isReady, let pending = self.readyContinuation else { return }
        self.readyContinuation = nil
        Self.log.error("SC READY 타임아웃(10s) — 위젯 미로드 → CC0 폴백")
        pending.resume(throwing: MutterError(.network))
      }
    }
  }

  public func play() {
    wantsPlay = true
    guard isReady else {
      Self.log.debug("SC play() 보류 — 위젯 준비 후 자동재생 예약")
      return
    }
    Self.log.debug("SC play() 실행")
    controller.evaluateJavaScript("window.scPlay && window.scPlay();")
  }

  public func pause() {
    wantsPlay = false
    controller.evaluateJavaScript("window.scPause && window.scPause();")
  }

  public func seek(toMs ms: Int) {
    controller.evaluateJavaScript("window.scSeek && window.scSeek(\(ms));")
  }

  public func setVolume(_ volume: Double) {
    // SC Widget 볼륨은 0~100.
    let percent = Int((max(0, min(1, volume)) * 100).rounded())
    controller.evaluateJavaScript("window.scVolume && window.scVolume(\(percent));")
  }

  public var attachmentView: AnyView? {
    AnyView(
      MutterWebView(
        source: .html(Self.playerHTML(trackURL: trackURL), baseURL: URL(string: "https://w.soundcloud.com")),
        controller: controller,
        messageHandlers: [Self.messageName],
        allowsAutoplayMedia: true,
        onMessage: { [weak self] _, body in
          self?.handleMessage(body)
        }
      )
      // 보이지 않게 — 오디오만 필요. 1pt 투명, 터치 비활성.
      .frame(width: 1, height: 1)
      .opacity(0.001)
      .allowsHitTesting(false)
    )
  }

  // MARK: - JS → 네이티브 메시지 처리

  private func handleMessage(_ body: Any) {
    guard
      let dict = body as? [String: Any],
      let event = dict["event"] as? String
    else { return }

    switch event {
    case "ready":
      guard !isReady else { return }
      isReady = true
      Self.log.debug("SC READY 수신 — 위젯 로드 완료")
      readyContinuation?.resume()
      readyContinuation = nil
      if startMs > 0 { seek(toMs: startMs) }
      if wantsPlay {
        Self.log.debug("SC READY 후 보류된 재생 실행")
        controller.evaluateJavaScript("window.scPlay && window.scPlay();")
      }
    case "finish":
      onFinish?()
    default:
      break
    }
  }

  // MARK: - SC Widget HTML

  private static let messageName = "sc"

  /// SC 공식 위젯 임베드 + JS 제어 셰임을 담은 HTML.
  private static func playerHTML(trackURL: URL) -> String {
    let encoded = trackURL.absoluteString
      .addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? trackURL.absoluteString
    let widgetSrc = "https://w.soundcloud.com/player/?url=\(encoded)"
      + "&auto_play=false&buying=false&sharing=false&download=false"
      + "&show_artwork=false&show_comments=false&show_user=false&visual=false"

    return """
    <!DOCTYPE html>
    <html>
    <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
    <body style="margin:0;background:transparent;">
      <iframe id="sc" width="100%" height="100" frameborder="no" allow="autoplay"
        src="\(widgetSrc)"></iframe>
      <script src="https://w.soundcloud.com/player/api.js"></script>
      <script>
        var widget = SC.Widget(document.getElementById('sc'));
        function post(ev){
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(messageName)) {
            window.webkit.messageHandlers.\(messageName).postMessage({event: ev});
          }
        }
        widget.bind(SC.Widget.Events.READY, function(){ post('ready'); });
        widget.bind(SC.Widget.Events.FINISH, function(){ post('finish'); });
        window.scPlay = function(){ widget.play(); };
        window.scPause = function(){ widget.pause(); };
        window.scSeek = function(ms){ widget.seekTo(ms); };
        window.scVolume = function(v){ widget.setVolume(v); };
      </script>
    </body>
    </html>
    """
  }
}

private extension CharacterSet {
  /// URL 쿼리 값에 안전한 문자(트랙 URL을 url= 파라미터로 넣을 때).
  static let urlQueryValueAllowed: CharacterSet = {
    var set = CharacterSet.urlQueryAllowed
    set.remove(charactersIn: "&=?#+/")
    return set
  }()
}
