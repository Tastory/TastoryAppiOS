//
//  ExitButton.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class ExitButton: UIButton {

  private struct Defaults {
    static let unpressedScale: CGFloat = 0.9
  }
  
  var crossLayer = CameraCrossLayer()
  var pressedCrossLayer = CameraCrossLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.frame = frame
    createLayers()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    createLayers()
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    crossLayer.animateIn()
  }
  
  func createLayers() {
    let scale = Defaults.unpressedScale
    let smallerRect = bounds.insetBy(dx: bounds.width*(1-scale)/2,
                                     dy: bounds.width*(1-scale)/2)
    crossLayer = CameraCrossLayer(frame: smallerRect)
    pressedCrossLayer = CameraCrossLayer(frame: bounds)
    layer.addSublayer(pressedCrossLayer)
    layer.addSublayer(crossLayer)
    pressedCrossLayer.isHidden = true
  }
  
  override var isHighlighted: Bool {
    didSet {
      if isHighlighted {
        crossLayer.isHidden = true
        pressedCrossLayer.isHidden = false
      } else {
        crossLayer.isHidden = false
        pressedCrossLayer.isHidden = true
      }
    }
  }
}
