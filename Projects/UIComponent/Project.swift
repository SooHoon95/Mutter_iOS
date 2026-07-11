import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "UIComponent",
  platform: .iOS,
  dependencies: [
    .appFoundation,
    .lottie
  ],
  testDependencies: [],
  resourceSynthesizers: [
    .assets()
  ]
)
