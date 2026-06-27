import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "MainTab",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
