import UIKit

import AppFoundation
import Domain

import GoogleSignIn

/// Google 로그인 — GIDSignIn으로 id_token 획득 → Supabase `signInSocial(.google)`.
/// (GIDSignIn.sharedInstance는 AppDelegate에서 clientID로 구성한다.)
struct GoogleSignInProvider: OauthSignInable {
  @MainActor
  func signIn() async throws -> OauthCredential {
    guard let presenter = Self.topViewController() else {
      throw MutterError(.server("로그인 화면을 열 수 없어요."))
    }
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
    guard let idToken = result.user.idToken?.tokenString else {
      throw MutterError(.server("Google 토큰을 받지 못했어요."))
    }
    return .social(provider: .google, token: idToken)
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
      .windows.first(where: { $0.isKeyWindow })?.rootViewController
  }
}
