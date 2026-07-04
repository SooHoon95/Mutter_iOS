//
//  ShadowView.swift
//  UIComponent
//
//  Created by 최수훈 on 7/4/26.
//

import SwiftUI

import UIComponent

struct ShadowView: View {
  
  var shadows: [MutterShadow] = [.shadowLow, .shadowMediumLow, .shadowMedium, .shadowHigh, .shadowHighest]
  
  var body: some View {
    VStack(spacing: 10) {
      
      ForEach(shadows, id: \.self) { shadow in
        MutterButton("Button") {
          
        }
        .shadows(shadow)
      }
    }
  }
}
