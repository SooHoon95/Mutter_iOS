//
//  Dependency+Extension.swift
//  Packages
//
//  (Mercury 스캐폴드 복제 — Mutter용 외부/내부 의존성 정의)
//

import ProjectDescription

public extension TargetDependency {
  // MARK: - 외부 SDK
  static let supabase: TargetDependency = .external(name: "Supabase")
  static let googleSignIn: TargetDependency = .external(name: "GoogleSignIn")
  static let googleSignInSwift: TargetDependency = .external(name: "GoogleSignInSwift")
  static let kakaoUser: TargetDependency = .external(name: "KakaoSDKUser")
  static let kakaoAuth: TargetDependency = .external(name: "KakaoSDKAuth")
  static let lottie: TargetDependency = .external(name: "Lottie")
  static let firebaseCore: TargetDependency = .external(name: "FirebaseCore")
  static let firebaseMessaging: TargetDependency = .external(name: "FirebaseMessaging")
  static let firebaseCrashlytics: TargetDependency = .external(name: "FirebaseCrashlytics")
  static let firebaseAnalytics: TargetDependency = .external(name: "FirebaseAnalytics")
  static let pulse: TargetDependency = .external(name: "Pulse")
  static let pulseProxy: TargetDependency = .external(name: "PulseProxy")
  static let pulseUI: TargetDependency = .external(name: "PulseUI")
  static let swiftTesting: TargetDependency = .external(name: "Testing")

  // MARK: - 내부 모듈 (레이어)
  static let appFoundation: TargetDependency = .project(target: "AppFoundation", path: .relativeToRoot("Projects/AppFoundation"))
  static let networking: TargetDependency = .project(target: "Networking", path: .relativeToRoot("Projects/Network"))
  static let uiComponent: TargetDependency = .project(target: "UIComponent", path: .relativeToRoot("Projects/UIComponent"))
  static let router: TargetDependency = .project(target: "Router", path: .relativeToRoot("Projects/Router"))
  static let domain: TargetDependency = .project(target: "Domain", path: .relativeToRoot("Projects/Domain"))
  static let infrastructure: TargetDependency = .project(target: "Infrastructure", path: .relativeToRoot("Projects/Infrastructure"))
  static let audioSync: TargetDependency = .project(target: "AudioSync", path: .relativeToRoot("Projects/AudioSync"))

  // MARK: - Feature 동적 참조
  static func feature(target: String) -> TargetDependency {
    return .project(target: target, path: .featurePath(target))
  }
}
