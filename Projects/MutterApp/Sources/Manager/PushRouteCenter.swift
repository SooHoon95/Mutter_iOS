import Combine
import Foundation

/// 알림 탭 → 화면 라우팅 신호. `AppDelegate`(알림 응답)가 쓰고 `MainView`가 구독해 화면을 연다.
/// 콜드 스타트에선 알림 응답이 `MainView` 구독보다 먼저 올 수 있어 마지막 값을 들고 있는
/// `CurrentValueSubject`로 둔다(소비한 쪽이 `consume`으로 비운다).
final class PushRouteCenter {
  static let shared = PushRouteCenter()

  /// 탭된 보낸 사람 알림(만료·간직 요청)이 가리키는 보낸 편지 id.
  let sentLetterId = CurrentValueSubject<String?, Never>(nil)

  /// 보낸 사람에게 오는 푸시 — 탭하면 그 보낸 편지 상세(계약 `docs/specs/permanent-letter-contract.md` "푸시").
  /// `letter_kept`(간직 요청자에게)는 받은 편지함 탭으로 바꿀 경로가 없어 기본 앱 열기로 둔다.
  private static let sentLetterTypes: Set<String> = ["letter_lock_soon", "letter_locked", "letter_keep_request"]

  private init() {}

  /// 알림 data(`type`, `letter_id`)를 해석해 라우팅 신호를 낸다. 모르는 알림은 무시한다.
  func handle(userInfo: [AnyHashable: Any]) {
    guard let type = userInfo["type"] as? String,
          Self.sentLetterTypes.contains(type),
          let letterId = userInfo["letter_id"] as? String,
          !letterId.isEmpty else { return }
    sentLetterId.send(letterId)
  }

  func consume() {
    sentLetterId.send(nil)
  }
}
