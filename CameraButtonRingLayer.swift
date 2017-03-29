//
//  CameraButtonRingLayer.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-28.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class CameraButtonRingLayer: CAShapeLayer {
  
  private struct Defaults {
    static let smallCircleScale: CGFloat = 0.85
    static let smallAlpha: CGFloat = 0.7
    static let smallWidth: CGFloat = 3.0

    static let largeAlpha: CGFloat = 0.7
    static let largeWidth: CGFloat = 10.0
  }
  
  let smallColor = UIColor.white
  let largeColor = UIColor.red
  
  let smallStrokeDuration: CFTimeInterval = CameraViewController.Defaults.animateInDuration
  let smallToLargeDuration: CFTimeInterval = CameraViewController.Defaults.cameraButtonOnDuration
  let largeToSmallDuration: CFTimeInterval = CameraViewController.Defaults.cameraButtonOffDuration
  let largeUnstrokeDuration: CFTimeInterval = 10.0 // need to match recording max duration
  
  convenience init (frame: CGRect) {
    self.init()
    self.frame = frame
    fillColor = UIColor.clear.cgColor
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    path = smallCircle.cgPath
  }
  
  private var smallCircle: UIBezierPath {
    let scale = Defaults.smallCircleScale
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    lineWidth = Defaults.smallWidth
    strokeColor = smallColor.withAlphaComponent(Defaults.smallAlpha).cgColor
    return UIBezierPath(arcCenter: CGPoint(x: newRect.midX, y: newRect.midY),
                        radius: min(newRect.width/2, newRect.height/2),
                        startAngle: CGFloat.pi*3/2,
                        endAngle: CGFloat.pi*7/2,
                        clockwise: true)
  }
  
  private var largeCircle: UIBezierPath {
    lineWidth = Defaults.largeWidth
    strokeColor = largeColor.withAlphaComponent(Defaults.largeAlpha).cgColor
    return UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                        radius: min(bounds.width/2, bounds.height/2),
                        startAngle: CGFloat.pi*3/2,
                        endAngle: CGFloat.pi*7/2,
                        clockwise: true)
  }
  
  func animateStrokeSmallCircle() {
    let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
    strokeAnimation.fromValue = 0.0
    strokeAnimation.toValue = 1.0
    strokeAnimation.duration = smallStrokeDuration
    strokeAnimation.isRemovedOnCompletion = true
    add(strokeAnimation, forKey: "strokeEnd")
  }
  
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
  
  func animateLargeUnstroke() {
    let unstrokeAnimation = CABasicAnimation(keyPath: "strokeStart")
    unstrokeAnimation.fromValue = 0.0
    unstrokeAnimation.toValue = 1.0
    unstrokeAnimation.duration = largeUnstrokeDuration
    unstrokeAnimation.isRemovedOnCompletion = true
    add(unstrokeAnimation, forKey: "strokeStart")
  }
  
  func animatePauseAnimations() {
    let pauseTime = convertTime(CACurrentMediaTime(), from: nil)
    speed = 0.0
    timeOffset = pauseTime
  }
}
