import AuthenticationServices
import CryptoKit
import UIKit

import AppFoundation
import Domain

/// Apple 로그인 — ASAuthorization + nonce → id_token → Supabase `signInApple(idToken:nonce:)`.
@MainActor
final class AppleSignInProvider: NSObject, OauthSignInable {
  private var continuation: CheckedContinuation<OauthCredential, Error>?
  private var currentNonce = ""

  func signIn() async throws -> OauthCredential {
    let nonce = Self.randomNonce()
    currentNonce = nonce

    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = Self.sha256(nonce)

    return try await withCheckedThrowingContinuation { cont in
      self.continuation = cont
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }

  // MARK: - nonce (Supabase가 요구: 요청엔 SHA256 해시, 교환엔 원문)

  private static func randomNonce(length: Int = 32) -> String {
    let charset = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._")
    var bytes = [UInt8](repeating: 0, count: length)
    _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
    return String(bytes.map { charset[Int($0) % charset.count] })
  }

  private static func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

extension AppleSignInProvider: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard
      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenData = credential.identityToken,
      let idToken = String(data: tokenData, encoding: .utf8)
    else {
      continuation?.resume(throwing: MutterError(.server("Apple 토큰을 받지 못했어요.")))
      continuation = nil
      return
    }
    continuation?.resume(returning: .apple(idToken: idToken, nonce: currentNonce))
    continuation = nil
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

extension AppleSignInProvider: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
      .windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
  }
}
