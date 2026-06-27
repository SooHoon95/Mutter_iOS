import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Viewer",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain,
    .audioSync
  ],
  testDependencies: []
)
