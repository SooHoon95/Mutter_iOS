//
//  Project+Application.swift
//  Packages
//
//  Created by 송하민 on 7/11/24.
//

import ProjectDescription

extension Project {
  
  public static func app(
    name: String,
    destinations: Destinations,
    platform: Platform,
    dependencies: [TargetDependency],
    testDependencies: [TargetDependency]
  ) -> Project {
    
    let targets = makeAppTargets(
      name: name,
      destinations: destinations,
      // L10n 코드젠(localization·swiftGen)은 Mutter 미사용(색은 모듈별 resourceSynthesizers).
      // 빌드 시 SwiftLint만 유지(품질). 입력 누락으로 깨지지 않게 lint만 둔다.
      scripts: [
        .prebuildScript(.swiftLint, name: "Lint")
      ],
      dependencies: dependencies,
      testDependencies: testDependencies
    )
    
    return Project(
      name: name,
      settings: .settings(
        configurations: Configuration.mainAppConfigure()
      ),
      targets: targets,
      resourceSynthesizers: []
    )
  }
  
  // MARK: - Targets
  
  private static func makeAppTargets(
    name: String,
    destinations: Destinations,
    productName: String? = productName,
    bundleId: String = bundleId,
    deploymentTargets: DeploymentTargets? = deploymentTarget,
    scripts: [TargetScript],
    dependencies: [TargetDependency],
    testDependencies: [TargetDependency],
    coreDataModels: [CoreDataModel] = []
  ) -> [Target] {
    
    let mainTarget: Target = .target(
      name: name,
      destinations: destinations,
      product: .app,
      productName: productName,
      bundleId: bundleId,
      deploymentTargets: deploymentTargets,
      infoPlist: .file(path: .infoPlistPath("MutterAppInfo")),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      entitlements: Project.commonEntitlement,
      scripts: scripts,
      dependencies: dependencies,
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon"
        ],
        configurations: Configuration.mainAppConfigure()
      ),
      coreDataModels: coreDataModels
    )
    
    let testTarget: Target = .target(
      name: "\(name)Tests",
      destinations: destinations,
      product: .unitTests,
      bundleId: "\(bundleId)Tests",
      deploymentTargets: deploymentTargets,
      sources: ["Tests/**"],
      resources: [],
      scripts: scripts,
      dependencies: [.target(name: name)] + testDependencies,
      settings: .settings(configurations: Configuration.mainAppConfigure())
    )
    
    return [mainTarget, testTarget]
  }
}
