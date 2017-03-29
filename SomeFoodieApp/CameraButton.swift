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
    static let buttonRectScale: CGFloat = 0.6
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
  
  func createLayers() {
    let scale = Defaults.buttonRectScale
    let buttonRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    buttonLayer = CameraButtonLayer(frame: buttonRect)
    layer.addSublayer(buttonLayer)
    buttonLayer.smallToMedium()
  }
  
  func buttonPressed() {
    buttonLayer.mediumToLarge()
  }
  
  func buttonReleased() {
    buttonLayer.largeToMedium()
  }
  
  func startRecording() {
    // Kick off animation
  }
  
  func stopRecording() {
    // Reverse animation
  }
}
