import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Router",
  platform: .iOS,
  dependencies: [
    .appFoundation
  ],
  testDependencies: []
)
