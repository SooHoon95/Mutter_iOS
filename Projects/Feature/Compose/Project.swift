import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Compose",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain,
    .audioSync
  ],
  testDependencies: []
)
