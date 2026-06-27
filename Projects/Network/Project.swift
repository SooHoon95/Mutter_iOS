import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Networking",
  platform: .iOS,
  dependencies: [
    .appFoundation,
    .pulse,
    .pulseProxy,
    .pulseUI
  ],
  testDependencies: []
)
