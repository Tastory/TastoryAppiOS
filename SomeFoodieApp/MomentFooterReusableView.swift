//
//  MomentFooterReusableView.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class MomentFooterReusableView: UICollectionReusableView {
  
  private struct Constants {
    static let addMomentIconInsetPct: CGFloat = 0.3
  }
  
  var addMomentLayer = AddMomentLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.frame = frame
    createLayers()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    createLayers()
  }
  
  private func createLayers() {
    addMomentLayer = AddMomentLayer(frame: bounds.insetBy(dx: bounds.maxX*Constants.addMomentIconInsetPct,
                                                          dy: bounds.maxY*Constants.addMomentIconInsetPct))
    addMomentLayer.lineWidth = 2.0
    addMomentLayer.strokeColor = UIColor.orange.cgColor
    layer.addSublayer(addMomentLayer)
  }
}
