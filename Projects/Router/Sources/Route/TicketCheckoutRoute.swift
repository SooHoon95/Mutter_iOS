import SwiftUI

/// 결제 안내 시트가 무엇을 위해 뜨는지 — 문구(보내는 사람/받는 사람)와 구매 뒤에 이어서 할 일이 달라진다.
/// 편지권이 없는 계정이 편지권이 필요한 동작을 눌렀을 때만 뜬다(있으면 그 자리에서 바로 쓴다).
public enum TicketCheckoutRoute: Hashable, Identifiable {
  /// 보내는 사람, 아직 안 보낸 편지 — 보내기 전 선택에서 영구 편지를 골랐다. **구매만 한다.**
  /// 편지권은 여기서 쓰지 않고, 링크를 만들거나 보낼 때 서버가 같은 트랜잭션에서 쓴다.
  case sendPermanent
  /// 보내는 사람, 이미 보낸 편지 — "영구 편지로 만들기". 구매하고 바로 쓴다.
  case makePermanent(letterId: String)
  /// 받는 사람 — 받은 편지를 간직한다(편지 끝·닫힘 예고·잠김 화면). 구매하고 바로 쓴다. `password`는 링크 암호(없으면 nil).
  case keepReceived(token: String, password: String?)

  public var id: Self { self }
}

/// 결제 안내 시트를 만드는 클로저. Feature는 서로 의존할 수 없어, 앱이 Ticket 모듈의 화면을 만들어 주입한다.
/// 두 번째 인자는 시트가 끝났을 때 — `true`면 하려던 일을 마쳤다(`sendPermanent`는 편지권 확보, 나머지는 편지권 사용까지).
public typealias TicketCheckoutBuilder = (TicketCheckoutRoute, @escaping (Bool) -> Void) -> AnyView
