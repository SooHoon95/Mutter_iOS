//
//  OverlayWindowGroup.swift
//  UIComponent
//
//  Created by 최수훈 on 7/2/26.
//

import SwiftUI
import UIKit

public struct OverlayGroup: View {
  public var body: some View {
    ZStack {
      MutterLoadingView()
    }
  }
}

public struct OverlayWindowView<Content: View>: View {
  public var content: Content
  @State private var overlayWindow: UIWindow?
  
  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }
  
  public var body: some View {
    ZStack {
      content
        .overlay(alignment: .center) {
          OverlayGroup()
            .allowsHitTesting(true)
        }
    }
  }
}
