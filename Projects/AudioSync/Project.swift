import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "AudioSync",
  platform: .iOS,
  dependencies: [
    .domain,
    .uiComponent
  ],
  testDependencies: []
)
