//
//  ImagePickerButton.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-09.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class ImagePickerButton: UIButton {

  private struct Constants {
    static let unpressedScale: CGFloat = 0.9  // The X is smaller when unpressed compared to when depressed. This is the scale to apply
  }
  
  var squareLayer = PickerSquareLayer()
  var pressedSquareLayer = PickerSquareLayer()
  
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
    squareLayer.animateIn()
  }
  
  private func createLayers() {
    
    // The Unpressed cross is made smaller than max size. Max size is reserved for the Pressed cross
    let scale = Constants.unpressedScale
    let smallerRect = bounds.insetBy(dx: bounds.width*(1-scale)/2,
                                     dy: bounds.width*(1-scale)/2)
    squareLayer = PickerSquareLayer(frame: smallerRect)
    pressedSquareLayer = PickerSquareLayer(frame: bounds)
    layer.addSublayer(squareLayer)
    layer.addSublayer(pressedSquareLayer)
    pressedSquareLayer.isHidden = true  // As seen above both the unpressed and pressed crosses are pre-made ahead of time. But the press crossed is initially hidden
  }
  
  
  // This is how the cross is 'animated' when pressed/depressed
  override var isHighlighted: Bool {
    didSet {
      if isHighlighted {
        squareLayer.isHidden = true
        pressedSquareLayer.isHidden = false
      } else {
        squareLayer.isHidden = false
        pressedSquareLayer.isHidden = true
      }
    }
  }
}
