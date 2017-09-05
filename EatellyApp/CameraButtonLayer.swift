//
//  CameraButtonLayer.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-28.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class CameraButtonLayer: CAShapeLayer {
  
  private struct Constants {
    static let smallShapeScale: CGFloat = 0.1  // Size of the small circle as comapred to max size (size of the large red circle)
    static let mediumShapeScale: CGFloat = 0.55  // Size of the rounded rectange as compared to the max size (size of the large red cirlce)
    static let cornerRadiusPercent: CGFloat = 0.15
    static let alphaValue: CGFloat = 0.6
  }
  
  let smallColor = UIColor.white
  let mediumColor = UIColor.white
  let largeColor = UIColor.red
  var sToMDuration: CFTimeInterval = CameraViewController.GlobalConstants.animateInDuration
  var mToLDuration: CFTimeInterval = CameraViewController.GlobalConstants.cameraButtonOnDuration
  var lToMDuration: CFTimeInterval = CameraViewController.GlobalConstants.cameraButtonOffDuration
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    path = smallCircle.cgPath
  }
  
  
  // Small circle just before the camera screen loads
  private var smallCircle: UIBezierPath {
    let scale = Constants.smallShapeScale
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2) // Scaling by scaling factor
    fillColor = smallColor.withAlphaComponent(Constants.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: newRect.width/2) // This is essentially a circle
  }
  
  
  // Rounded rectangle as part of the unpressed button
  private var mediumRoundedRectangle: UIBezierPath {
    let scale = Constants.mediumShapeScale
    let cornerRadius = min(bounds.width, bounds.height)*Constants.cornerRadiusPercent
    let newRect = bounds.insetBy(dx: bounds.width*(1-scale)/2, dy: bounds.height*(1-scale)/2) // Scaling by scaling factor
    fillColor = mediumColor.withAlphaComponent(Constants.alphaValue).cgColor
    return UIBezierPath(roundedRect: newRect, cornerRadius: cornerRadius)
  }
  
  
  // Large red circle after the button is pressed (full size as recording is in progress)
  private var largeCircle: UIBezierPath {
    fillColor = largeColor.withAlphaComponent(Constants.alphaValue).cgColor
    return UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width/2) // This is essentially a circle
  }
  
  
  // The middle rectangle zooms in and becomes larger when the camera screen loads
  func animateSmallToMedium () {
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = smallCircle.cgPath
    animation.toValue = mediumRoundedRectangle.cgPath
    animation.duration = sToMDuration
    animation.isRemovedOnCompletion = true
    path = mediumRoundedRectangle.cgPath
    add(animation, forKey: "path")
  }
  
  
  // The middle rectange becomes a red circle when pressed
  func animateMediumToLarge() {
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = mediumRoundedRectangle.cgPath
    animation.toValue = largeCircle.cgPath
    animation.duration = mToLDuration
    animation.isRemovedOnCompletion = true
    path = largeCircle.cgPath
    add(animation, forKey: "path")
  }
  
  
  // Red circle becomes a white rounded rectangle again when unpressed
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
