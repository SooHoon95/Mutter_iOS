import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "AudioSync",
  platform: .iOS,
  dependencies: [
    .appFoundation,
    .domain,
    .uiComponent
  ],
  testDependencies: []
)
