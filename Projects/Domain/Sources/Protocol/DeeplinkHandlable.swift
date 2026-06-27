import Foundation

/// 딥링크 처리 계약(구현은 Router/App — `/l/:token`→Viewer, `/connect/:token`→Connect).
/// URL만 받아 결합도를 낮춘다(파싱은 AppFoundation `Deeplink`가 담당).
public protocol DeeplinkHandlable {
  func handle(url: URL)
}
