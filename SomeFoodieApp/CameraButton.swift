//
//  CameraButton.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-27.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import SwiftyCam

class CameraButton: SwiftyCamButton {

  private struct Defaults {
    static let buttonRectScale: CGFloat = 0.75
  }
  
  var ringLayer = CameraButtonRingLayer()
  var buttonLayer = CameraButtonLayer()
  // TODO: Busy Indicator Layer
  
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
    buttonLayer.animateSmallToMedium()
    ringLayer.animateStrokeSmallCircle()
  }
  
  func createLayers() {
    let scale = Defaults.buttonRectScale
    let buttonRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    buttonLayer = CameraButtonLayer(frame: buttonRect)
    ringLayer = CameraButtonRingLayer(frame: bounds)
    layer.addSublayer(buttonLayer)
    layer.addSublayer(ringLayer)
    
  }
  
  
  func buttonPressed() {
    buttonLayer.animateMediumToLarge()
    ringLayer.animateSmallToLarge()
  }
  
  func buttonReleased() {
    buttonLayer.animateLargeToMedium()
    ringLayer.animateLargeToSmall()
  }
  
  func startRecording() {
    ringLayer.animateLargeUnstroke()
  }
  
  func stopRecording() {
    ringLayer.animatePauseAnimations()
  }
}
