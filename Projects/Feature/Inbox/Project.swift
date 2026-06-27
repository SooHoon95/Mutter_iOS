import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Inbox",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
