import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  name: "Mutter",
  destinations: .iOS,
  platform: .iOS,
  dependencies: [
    .feature(target: "Auth"),
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
    .infrastructure,
    .router,
    .audioSync,
    .uiComponent,
    .firebaseCore,
    .firebaseMessaging,
    .firebaseCrashlytics,
    .firebaseAnalytics,
    .googleSignIn,
    .kakaoUser
  ],
  testDependencies: []
)
