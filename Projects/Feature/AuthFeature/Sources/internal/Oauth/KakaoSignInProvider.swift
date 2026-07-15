import Foundation

import AppFoundation
import Domain
import UIComponent

import KakaoSDKAuth
import KakaoSDKUser

/// Kakao 로그인 — 카카오톡/계정 로그인 → OIDC id_token → Supabase `signInSocial(.kakao)`.
/// (KakaoSDK.initSDK는 AppDelegate에서 appKey로 초기화한다. id_token은 콘솔 OpenID Connect 활성 필요.)
struct KakaoSignInProvider: OauthSignInable {
  @MainActor
  func signIn() async throws -> OauthCredential {
    let token: OAuthToken = try await withCheckedThrowingContinuation { cont in
      let handler: (OAuthToken?, Error?) -> Void = { token, error in
        if let error { cont.resume(throwing: error); return }
        guard let token else {
          cont.resume(throwing: MutterError(.server(L10n.authErrorKakaoFailed))); return
        }
        cont.resume(returning: token)
      }
      if UserApi.isKakaoTalkLoginAvailable() {
        UserApi.shared.loginWithKakaoTalk(completion: handler)
      } else {
        UserApi.shared.loginWithKakaoAccount(completion: handler)
      }
    }
    guard let idToken = token.idToken else {
      throw MutterError(.server(L10n.authErrorKakaoNoIdToken))
    }
    return .social(provider: .kakao, token: idToken)
  }
}
