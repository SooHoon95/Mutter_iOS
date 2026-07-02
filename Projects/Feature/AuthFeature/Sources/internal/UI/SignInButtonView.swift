import SwiftUI

/// provider 종류에 맞는 소셜 로그인 버튼을 그린다(Mercury `SignInButtonView` 대응).
struct SignInButtonView: View {
  let type: OauthProvider
  let completion: () async -> Void

  var body: some View {
    Group {
      switch type {
      case .apple:
        AppleSignInButton(completion: completion)
      case .google:
        GoogleSignInButtonView(completion: completion)
      case .kakao:
        KakaoSignInButtonView(completion: completion)
      }
    }
  }
}
