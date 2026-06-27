import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Networking",
  platform: .iOS,
  dependencies: [
    .appFoundation,
    .supabase,
    .pulse,
    .pulseProxy,
    .pulseUI
  ],
  testDependencies: []
)
