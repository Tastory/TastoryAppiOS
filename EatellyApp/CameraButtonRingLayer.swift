//
//  CameraButtonRingLayer.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-28.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class CameraButtonRingLayer: CAShapeLayer {
  
  private struct Constants {
    static let smallCircleScale: CGFloat = 0.80  // Size of the ring when capture button is unpressed, as a percentage of the pressed larger ring
    static let smallAlpha: CGFloat = 0.7
    static let smallWidth: CGFloat = 3.0  // Stroke width of the ring when capture button is unpressed

    static let largeAlpha: CGFloat = 0.7
    static let largeWidth: CGFloat = 10.0  // Stroke width of the ring when capture button have been pressed
  }
  
  let smallColor = UIColor.white
  let largeColor = UIColor.red
  
  let smallStrokeDuration: CFTimeInterval = CameraViewController.GlobalConstants.animateInDuration
  let smallToLargeDuration: CFTimeInterval = CameraViewController.GlobalConstants.cameraButtonOnDuration
  let largeToSmallDuration: CFTimeInterval = CameraViewController.GlobalConstants.cameraButtonOffDuration
  let largeUnstrokeDuration: CFTimeInterval = 10.0 // need to match recording max duration
  
  
  convenience init (frame: CGRect) {
    self.init()
    self.frame = frame
    fillColor = UIColor.clear.cgColor
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    path = smallCircle.cgPath
  }
  
  
  // Ring when the capture button is not pressed
  private var smallCircle: UIBezierPath {
    let scale = Constants.smallCircleScale
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    lineWidth = Constants.smallWidth
    strokeColor = smallColor.withAlphaComponent(Constants.smallAlpha).cgColor
    return UIBezierPath(arcCenter: CGPoint(x: newRect.midX, y: newRect.midY),
                        radius: min(newRect.width/2, newRect.height/2),
                        startAngle: CGFloat.pi*3/2,
                        endAngle: CGFloat.pi*7/2,
                        clockwise: true)
  }
  
  
  // Ring when the cpature button have been pressed
  private var largeCircle: UIBezierPath {
    lineWidth = Constants.largeWidth
    strokeColor = largeColor.withAlphaComponent(Constants.largeAlpha).cgColor
    return UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                        radius: min(bounds.width/2, bounds.height/2),
                        startAngle: CGFloat.pi*3/2,
                        endAngle: CGFloat.pi*7/2,
                        clockwise: true)
  }
  
  
  // What's left of the ring at the end of the 10 seconds recording window - aka. Just a dot at the 12 o'clock position.
  private var dotCircle: UIBezierPath {
    lineWidth = Constants.largeWidth
    strokeColor = largeColor.withAlphaComponent(Constants.largeAlpha).cgColor
    return UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                        radius: min(bounds.width/2, bounds.height/2),
                        startAngle: CGFloat.pi*29/20,
                        endAngle: CGFloat.pi*3/2,
                        clockwise: true)
  }
  
  
  // As the camera view is loading, the ring gets stroked clockwise
  func animateStrokeSmallCircle() {
    let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
    strokeAnimation.fromValue = 0.0
    strokeAnimation.toValue = 1.0
    strokeAnimation.duration = smallStrokeDuration
    strokeAnimation.isRemovedOnCompletion = true
    add(strokeAnimation, forKey: "strokeEnd")
  }
  
  
  // As the capture button is pressed, the ring enlarges
  func animateSmallToLarge() {
    let pathAnimation = CABasicAnimation(keyPath: "path")
    pathAnimation.fromValue = smallCircle.cgPath
    pathAnimation.toValue = largeCircle.cgPath
    pathAnimation.beginTime = 0.0
    pathAnimation.duration = smallToLargeDuration
    pathAnimation.isRemovedOnCompletion = true
    path = largeCircle.cgPath
    add(pathAnimation, forKey: "path")
  }
  
  
  // As the capture button is released, the ring becomes smaller again
  func animateLargeToSmall() {
    let pathAnimation = CABasicAnimation(keyPath: "path")
    pathAnimation.fromValue = largeCircle.cgPath
    pathAnimation.toValue = smallCircle.cgPath
    pathAnimation.beginTime = 0.0
    pathAnimation.duration = largeToSmallDuration
    pathAnimation.isRemovedOnCompletion = true
    path = smallCircle.cgPath
    add(pathAnimation, forKey: "path")
  }
  
  
  // When video is recording, the large ring gets unstroked clockwise
  func animateLargeUnstroke() {
    let unstrokeAnimation = CABasicAnimation(keyPath: "strokeStart")
    unstrokeAnimation.fromValue = 0.0
    unstrokeAnimation.toValue = 1.0
    unstrokeAnimation.duration = largeUnstrokeDuration
    unstrokeAnimation.fillMode = kCAFillModeForwards
    unstrokeAnimation.isRemovedOnCompletion = false
    add(unstrokeAnimation, forKey: "strokeStart")
  }
  
  
  // When recording stops, the stroking animation will pause in place
  func pauseAnimations() {
    let pauseTime = convertTime(CACurrentMediaTime(), from: nil)
    speed = 0.0
    timeOffset = pauseTime
  }
  
  
  // Animation needs to reset when a user discards a media from the markup view back to the camera view
  func resetAnimations() {
    removeAllAnimations()
    speed = 1.0
    timeOffset = 0.0
    strokeColor = smallColor.withAlphaComponent(Constants.smallAlpha).cgColor
  }
}
