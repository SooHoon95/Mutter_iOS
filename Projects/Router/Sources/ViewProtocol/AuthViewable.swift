import SwiftUI

/// 인증(로그인) 화면 계약(Mercury `SignInViewable` 대응). 인증 완료 시 `onComplete`로 합성 루트에 통지.
public protocol AuthViewable where Self: View {
  init(onComplete: (() -> Void)?)
}
