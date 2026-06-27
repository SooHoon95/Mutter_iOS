import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Profile",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain
  ],
  testDependencies: []
)
