//
//  CameraCrossLayer.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class CameraCrossLayer: CAShapeLayer {
  
  private struct Defaults {
    static let crossInsetPx: CGFloat = 10.0
    static let alphaValue: CGFloat = 0.8
    static let strokeWidth: CGFloat = 3.0
  }
  
  var animateInDuration: CFTimeInterval = CameraViewController.Defaults.animateInDuration
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    strokeColor = UIColor.white.withAlphaComponent(Defaults.alphaValue).cgColor
    lineWidth = Defaults.strokeWidth
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    path = normalCross.cgPath
  }
  
  private var normalCross: UIBezierPath {
    let inset: CGFloat = Defaults.crossInsetPx
    let newRect = bounds.insetBy(dx: inset, dy: inset)
    let crossPath = UIBezierPath()
    crossPath.move(to: newRect.origin)
    crossPath.addLine(to: CGPoint(x: newRect.maxX, y: newRect.maxY))
    crossPath.move(to: CGPoint(x: newRect.maxX, y: newRect.minY))
    crossPath.addLine(to: CGPoint(x: newRect.minX, y: newRect.maxY))
    return crossPath
  }
  
  func animateIn () {
    let animation = CABasicAnimation(keyPath: "strokeEnd")
    animation.fromValue = 0.0
    animation.toValue = 1.0
    animation.duration = animateInDuration
    animation.isRemovedOnCompletion = true
    add(animation, forKey: "strokeEnd")
  }
}
