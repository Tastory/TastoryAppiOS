//
//  CameraButton.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-27.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit
import SwiftyCam

class CameraButton: SwiftyCamButton {

  private struct Constants {
    static let buttonRectScale: CGFloat = 0.75  // There's a rounded rectangle in the middle of the button. This is the scale to apply
  }
  
  var ringLayer = CameraButtonRingLayer()
  var buttonLayer = CameraButtonLayer()
  // TODO: Busy Indicator Layer
  
  fileprivate var animationReady = false
  fileprivate var cameraSessionReady = false
  
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
    ringLayer.resetAnimations()
    ringLayer.animateStrokeSmallCircle()
    DispatchQueue.main.asyncAfter(deadline: .now() + CameraViewController.GlobalConstants.animateInDuration) { 
      self.animationIsReady()
    }
  }
  
  private func createLayers() {
    let scale = Constants.buttonRectScale
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
  
  
  // This is for when the button's been released after a photo
  func buttonReleased() {
    buttonLayer.animateLargeToMedium()
    ringLayer.animateLargeToSmall()
  }
  
  // This is for when the button's been released after a video, and failed
  func buttonReset() {
    buttonLayer.animateSmallToMedium()
    ringLayer.resetAnimations()
    ringLayer.animateStrokeSmallCircle()
    cameraSessionReady = false
    animationReady = false
  }
  
  func startRecording() {
    ringLayer.animateLargeUnstroke()
  }
  
  func stopRecording() {
    ringLayer.pauseAnimations()
  }
  
  func cameraSessionIsReady() {
    cameraSessionReady = true
    if animationReady == true {
      self.isEnabled = true
    }
  }
  
  func animationIsReady() {
    animationReady = true
    if cameraSessionReady == true {
      self.isEnabled = true
    }
  }
  
}
