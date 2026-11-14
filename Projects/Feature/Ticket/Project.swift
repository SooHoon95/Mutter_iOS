import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Ticket",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
