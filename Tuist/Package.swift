// swift-tools-version: 5.9
@preconcurrency import PackageDescription


#if TUIST
@preconcurrency import ProjectDescription
import ProjectDescriptionHelpers

let packageSettings = PackageSettings(
  productTypes: [
    "Supabase": .framework,
    "Auth": .framework,
    "PostgREST": .framework,
    "Realtime": .framework,
    "Storage": .framework,
    "Functions": .framework,
    // Firebase는 정적 링크(공식 권장). 동적 .framework로 빌드 시 FirebaseCoreInternal의
    // Swift 호환성 심볼(swiftCompatibilityConcurrency 등)이 링크에서 누락된다.
    "FirebaseCore": .staticFramework,
    "FirebaseMessaging": .staticFramework,
    "FirebaseCrashlytics": .staticFramework,
    "FirebaseAnalytics": .staticFramework,
    "Testing": .framework,
    "KakaoSDKCommon": .framework,
    "KakaoSDKAuth": .framework,
    "KakaoSDKUser": .framework,
    "GoogleSignIn": .framework,
    "GoogleSignInSwift": .framework,
    "Lottie": .framework,
    "Pulse": .framework,
    "PulseProxy": .framework,
    "PulseUI": .framework
  ],
  baseSettings: .settings(configurations: Configuration.frameworkConfigure())
)
#endif

let package = Package(
  name: "SwiftPackages",
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.9.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0"),
    .package(url: "https://github.com/kakao/kakao-ios-sdk", branch: "master"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.1"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "11.11.0")),
    .package(url: "https://github.com/kean/Pulse.git", from: "5.1.4")
  ]
)
