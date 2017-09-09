//
//  ExpandButton.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-08.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class ExpandButton: UIButton {

  var arrowLayer = ArrowLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.frame = frame
    createLayers()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    createLayers()
  }
  
//  override func didMoveToWindow() {
//    super.didMoveToWindow()
//    .animateIn()
//  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    arrowLayer.frame = bounds
    arrowLayer.setNeedsDisplay()
  }
  
  private func createLayers() {
    // The Unpressed cross is made smaller than max size. Max size is reserved for the Pressed cross
    arrowLayer = ArrowLayer(frame: bounds)
    layer.addSublayer(arrowLayer)
  }
  
  func rotateToExpand() {
    arrowLayer.animateRotateDown()
  }
  
  func rotateToCollapse() {
    arrowLayer.animateRotateUp()
  }
}
