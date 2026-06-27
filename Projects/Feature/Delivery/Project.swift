import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Delivery",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
