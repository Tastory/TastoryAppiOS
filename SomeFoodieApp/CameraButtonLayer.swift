//
//  CameraButtonLayer.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-28.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class CameraButtonLayer: CAShapeLayer {
  
  private struct Defaults {
    static let smallShapeScale: CGFloat = 0.1
    static let mediumShapeScale: CGFloat = 0.55
    static let cornerRadiusPercent: CGFloat = 0.15
    static let alphaValue: CGFloat = 0.6
  }
  
  let smallColor = UIColor.white
  let mediumColor = UIColor.white
  let largeColor = UIColor.red
  var sToMDuration: CFTimeInterval = CameraViewController.Defaults.animateInDuration
  var mToLDuration: CFTimeInterval = CameraViewController.Defaults.cameraButtonOnDuration
  var lToMDuration: CFTimeInterval = CameraViewController.Defaults.cameraButtonOffDuration
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    path = smallCircle.cgPath
  }
  
  private var smallCircle: UIBezierPath {
    let scale = Defaults.smallShapeScale
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2) // Scaling by scaling factor
    fillColor = smallColor.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: newRect.width/2) // This is essentially a circle
  }
  
  private var mediumRoundedRectangle: UIBezierPath {
    let scale = Defaults.mediumShapeScale
    let cornerRadius = min(bounds.width, bounds.height)*Defaults.cornerRadiusPercent
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2) // Scaling by scaling factor
    fillColor = mediumColor.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: cornerRadius)
  }
  
  private var largeCircle: UIBezierPath {
    fillColor = largeColor.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width/2) // This is essentially a circle
  }
  
  func animateSmallToMedium () {
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = smallCircle.cgPath
    animation.toValue = mediumRoundedRectangle.cgPath
    animation.duration = sToMDuration
    animation.isRemovedOnCompletion = true
    path = mediumRoundedRectangle.cgPath
    add(animation, forKey: "path")
  }
  
  func animateMediumToLarge() {
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = mediumRoundedRectangle.cgPath
    animation.toValue = largeCircle.cgPath
    animation.duration = mToLDuration
    animation.isRemovedOnCompletion = true
    path = largeCircle.cgPath
    add(animation, forKey: "path")
  }
  
  func animateLargeToMedium() {
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = largeCircle.cgPath
    animation.toValue = mediumRoundedRectangle.cgPath
    animation.duration = mToLDuration
    animation.isRemovedOnCompletion = true
    path = mediumRoundedRectangle.cgPath
    add(animation, forKey: "path")
  }
}
