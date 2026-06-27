import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Legal",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
