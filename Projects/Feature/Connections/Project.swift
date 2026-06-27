import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Connections",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
