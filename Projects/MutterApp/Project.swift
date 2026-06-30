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
    .firebaseAnalytics
    // 소셜 로그인(Google/Kakao) SDK는 네이티브 연동(Phase2 후반)에서 추가한다.
    // 현재 미사용이며, GoogleSignIn→GTMAppAuth가 Swift 호환성 심볼을 강제로드해 앱 링크를 깨므로 제외.
  ],
  testDependencies: []
)
