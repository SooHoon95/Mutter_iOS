import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  name: "Mutter",
  // iPhone 전용(포트레이트·UIRequiresFullScreen). `.iOS`는 iPad를 포함해 UIDeviceFamily=[1,2]가
  // 되어 App Store가 iPad 아이콘(167×167)을 요구 → 업로드 거부(90023). iPhone으로 한정한다.
  destinations: [.iPhone],
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
