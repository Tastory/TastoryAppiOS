//
//  CameraCrossLayer.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

class CameraCrossLayer: CAShapeLayer {
  
  private struct Constants {
    static let crossInsetPx: CGFloat = 10.0
    static let alphaValue: CGFloat = 0.8
    static let strokeWidth: CGFloat = 3.0
  }
  
  var animateInDuration: CFTimeInterval = CameraViewController.GlobalConstants.animateInDuration
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    strokeColor = UIColor.white.withAlphaComponent(Constants.alphaValue).cgColor
    lineWidth = Constants.strokeWidth
    lineCap = CAShapeLayerLineCap.round
    lineJoin = CAShapeLayerLineJoin.round
    path = normalCross.cgPath
  }
  
  
  // Cross shape to represent the exit button from the camera view
  private var normalCross: UIBezierPath {
    let inset: CGFloat = Constants.crossInsetPx
    let newRect = bounds.insetBy(dx: inset, dy: inset)
    let crossPath = UIBezierPath()
    crossPath.move(to: newRect.origin)
    crossPath.addLine(to: CGPoint(x: newRect.maxX, y: newRect.maxY))
    crossPath.move(to: CGPoint(x: newRect.maxX, y: newRect.minY))
    crossPath.addLine(to: CGPoint(x: newRect.minX, y: newRect.maxY))
    return crossPath
  }
  
  
  // When the camera view loads, the cross is stroked to animate in
  func animateIn () {
    let animation = CABasicAnimation(keyPath: "strokeEnd")
    animation.fromValue = 0.0
    animation.toValue = 1.0
    animation.duration = animateInDuration
    animation.isRemovedOnCompletion = true
    add(animation, forKey: "strokeEnd")
  }
}
