import Foundation

/// OauthProvider → 구체 provider 생성(Mercury `SignInProviderFactory` 대응).
struct SignInProviderFactory {
  @MainActor func createProvider(_ provider: OauthProvider) -> OauthSignInable {
    switch provider {
    case .apple: AppleSignInProvider()
    case .google: GoogleSignInProvider()
    case .kakao: KakaoSignInProvider()
    }
  }
}
