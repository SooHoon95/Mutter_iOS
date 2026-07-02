import Foundation

import Domain

/// 소셜 로그인 제공자 종류(팩토리·UI용). Apple은 전용 자격증명 플로우.
enum OauthProvider: CaseIterable, Identifiable {
  case apple, google, kakao
  var id: Self { self }
}

/// provider가 SDK 인증을 마치고 반환하는 자격증명 → Supabase 교환용.
enum OauthCredential {
  /// google/kakao — id_token을 `signInSocial(provider:token:)`로 교환.
  case social(provider: SocialProvider, token: String)
  /// apple — id_token + nonce를 `signInApple(idToken:nonce:)`로 교환.
  case apple(idToken: String, nonce: String)
}

/// 소셜 provider 계약(Mercury `OauthSignInable` 대응). SDK 플로우를 수행하고 자격증명을 낸다.
protocol OauthSignInable {
  func signIn() async throws -> OauthCredential
}
