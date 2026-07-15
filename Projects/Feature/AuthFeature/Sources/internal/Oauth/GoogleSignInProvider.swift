import UIKit

import AppFoundation
import Domain
import UIComponent

import GoogleSignIn

/// Google 로그인 — GIDSignIn으로 id_token 획득 → Supabase `signInSocial(.google)`.
/// (GIDSignIn.sharedInstance는 AppDelegate에서 clientID로 구성한다.)
struct GoogleSignInProvider: OauthSignInable {
  @MainActor
  func signIn() async throws -> OauthCredential {
    guard let presenter = Self.topViewController() else {
      throw MutterError(.server(L10n.authErrorOpenLogin))
    }
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
    guard let idToken = result.user.idToken?.tokenString else {
      throw MutterError(.server(L10n.authErrorGoogleToken))
    }
    return .social(provider: .google, token: idToken)
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
      .windows.first(where: { $0.isKeyWindow })?.rootViewController
  }
}
