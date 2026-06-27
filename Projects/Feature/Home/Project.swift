import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Home",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
