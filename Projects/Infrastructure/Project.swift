import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Infrastructure",
  platform: .iOS,
  dependencies: [
    .appFoundation,
    .domain,
    .networking,
    .supabase,
    .firebaseMessaging,
    .firebaseCrashlytics,
    .firebaseAnalytics
  ],
  testDependencies: []
)
