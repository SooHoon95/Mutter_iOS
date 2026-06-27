//
//  ProjectDefine.swift
//  MercuryManifests
//
//  Created by 송하민 on 7/11/24.
//

import ProjectDescription

public extension Project {
  
  // MARK: - project manifests
  
  static let appName: String = "Mutter"
  static let productName: String = "Mutter"
  static let bundleId = "com.efreedom.mutter"
  static let deploymentTarget: DeploymentTargets = .iOS("18.0")
  
  // MARK: - read file path
  
  static let commonEntitlement: Entitlements = .file(path: Path.entitlementPath("App"))
  
}
