import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Threads",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
