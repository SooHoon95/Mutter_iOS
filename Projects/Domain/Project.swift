import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Domain",
  platform: .iOS,
  dependencies: [
    .appFoundation
  ],
  testDependencies: []
)
