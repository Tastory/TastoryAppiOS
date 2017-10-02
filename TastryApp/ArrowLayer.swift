//
//  ArrowLayer.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-08.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ArrowLayer: CAShapeLayer {
  
  private struct Constants {
    static let alphaValue: CGFloat = 0.8
    static let strokeWidth: CGFloat = 1.0
    static let animateDuration: TimeInterval = 0.25
  }
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    strokeColor = UIColor.gray.withAlphaComponent(Constants.alphaValue).cgColor
    lineWidth = Constants.strokeWidth
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    fillColor = UIColor.clear.cgColor
    path = upArrow.cgPath
  }
  
  
  // Cross shape to represent the exit button from the camera view
  private var upArrow: UIBezierPath {
    let arrowPath = UIBezierPath()
    let insetBounds = bounds.insetBy(dx: bounds.width/4.0, dy: bounds.height/2.5)
    arrowPath.move(to: CGPoint(x: insetBounds.minX, y: insetBounds.maxY))
    arrowPath.addLine(to: CGPoint(x: insetBounds.midX, y: insetBounds.minY))
    arrowPath.addLine(to: CGPoint(x: insetBounds.maxX, y: insetBounds.maxY))
    return arrowPath
  }
  
  
  // When the camera view loads, the cross is stroked to animate in
  func animateRotateDown() {
    let animation = CABasicAnimation(keyPath: "transform.rotation")
    animation.fromValue = 0.0
    animation.toValue = CGFloat.pi
    animation.duration = Constants.animateDuration
    animation.isRemovedOnCompletion = false
    animation.fillMode = kCAFillModeForwards
    add(animation, forKey: "transform.rotation")
  }
  
  func animateRotateUp() {
    let animation = CABasicAnimation(keyPath: "transform.rotation")
    animation.fromValue = CGFloat.pi
    animation.toValue = 0
    animation.duration = Constants.animateDuration
    animation.isRemovedOnCompletion = false
    animation.fillMode = kCAFillModeForwards
    add(animation, forKey: "transform.rotation")
  }
}
