import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Auth",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
