import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  name: "Mutter",
  destinations: .iOS,
  platform: .iOS,
  dependencies: [
    .feature(target: "AuthFeature"),
    .feature(target: "Compose"),
    .feature(target: "Viewer"),
    .feature(target: "Delivery"),
    .feature(target: "Inbox"),
    .feature(target: "Connections"),
    .feature(target: "Threads"),
    .feature(target: "Profile"),
    .feature(target: "Home"),
    .feature(target: "MainTab"),
    .feature(target: "Legal"),
    .domain,
    .infrastructure,
    .appFoundation,
    .router,
    .audioSync,
    .uiComponent,
    .firebaseCore,
    .firebaseMessaging,
    .firebaseCrashlytics,
    .firebaseAnalytics,
    // 소셜 로그인 — AppDelegate에서 GIDSignIn 구성 + KakaoSDK 초기화.
    // (GoogleSignIn→GTMAppAuth Swift 호환성 심볼 링크 에러 시 Tuist/Package.swift에서 static으로.)
    .googleSignIn,
    .external(name: "KakaoSDKCommon")
  ],
  testDependencies: []
)
