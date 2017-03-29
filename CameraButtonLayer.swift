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
    static let smallShapeScale: CGFloat = 0.2
    static let mediumShapeScale: CGFloat = 0.7
    static let cornerRadiusPercent: CGFloat = 0.15
    static let alphaValue: CGFloat = 0.8
    static let sToMDuration: CFTimeInterval = 0.8
    static let mToLDuration: CFTimeInterval = 0.2
    static let lToMDuration: CFTimeInterval = 0.2
  }
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    path = smallCircle.cgPath
  }
  
  private var smallCircle: UIBezierPath {
    let scale = Defaults.smallShapeScale
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    fillColor = UIColor.white.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: newRect.width/2)
  }
  
  private var mediumRoundedRectangle: UIBezierPath {
    let scale = Defaults.mediumShapeScale
    let cornerRadius = min(bounds.width, bounds.height)*Defaults.cornerRadiusPercent
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2)
    fillColor = UIColor.white.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: cornerRadius)
  }
  
  private var largeCircle: UIBezierPath {
    fillColor = UIColor.red.withAlphaComponent(Defaults.alphaValue).cgColor
    return UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width/2)
  }
  
  func smallToMedium () {
    let animation: CABasicAnimation = CABasicAnimation(keyPath: "path")
    animation.fromValue = smallCircle.cgPath
    animation.toValue = mediumRoundedRectangle.cgPath
    animation.duration = Defaults.sToMDuration
    animation.fillMode = kCAFillModeForwards
    animation.isRemovedOnCompletion = false
    add(animation, forKey: nil)
  }
  
  func mediumToLarge() {
    let animation: CABasicAnimation = CABasicAnimation(keyPath: "path")
    animation.fromValue = mediumRoundedRectangle.cgPath
    animation.toValue = largeCircle.cgPath
    animation.duration = Defaults.mToLDuration
    animation.fillMode = kCAFillModeForwards
    animation.isRemovedOnCompletion = false
    add(animation, forKey: nil)
  }
  
  func largeToMedium() {
    let animation: CABasicAnimation = CABasicAnimation(keyPath: "path")
    animation.fromValue = largeCircle.cgPath
    animation.toValue = mediumRoundedRectangle.cgPath
    animation.duration = Defaults.mToLDuration
    animation.fillMode = kCAFillModeForwards
    animation.isRemovedOnCompletion = false
    add(animation, forKey: nil)
  }
}
