import SwiftUI

/// 결제 안내 시트가 무엇을 위해 뜨는지 — 문구(보내는 사람/받는 사람)와 구매 뒤에 이어서 할 일이 달라진다.
/// 편지권이 없는 계정이 편지권이 필요한 동작을 눌렀을 때만 뜬다(있으면 그 자리에서 바로 쓴다).
public enum TicketCheckoutRoute: Hashable, Identifiable {
  /// 보내는 사람 — 이 편지를 영구 편지로 보낸다(보내기 전 선택·"영구 편지로 만들기").
  case sendPermanent(letterId: String)
  /// 받는 사람 — 받은 편지를 간직한다(편지 끝·닫힘 예고·잠김 화면). `password`는 링크 암호(없으면 nil).
  case keepReceived(token: String, password: String?)

  public var id: Self { self }
}

/// 결제 안내 시트를 만드는 클로저. Feature는 서로 의존할 수 없어, 앱이 Ticket 모듈의 화면을 만들어 주입한다.
/// 두 번째 인자는 시트가 끝났을 때 — `true`면 편지권 사용(영구 전환·간직)까지 마쳤다.
public typealias TicketCheckoutBuilder = (TicketCheckoutRoute, @escaping (Bool) -> Void) -> AnyView
