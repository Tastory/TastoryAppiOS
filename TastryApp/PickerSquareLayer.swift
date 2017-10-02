//
//  PickerSquareLayer.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class PickerSquareLayer: CAShapeLayer {

  private struct Constants {
    static let squareInsetPx: CGFloat = 8.0
    static let alphaValue: CGFloat = 0.8
    static let strokeWidth: CGFloat = 3.0
  }
  
  var animateInDuration: CFTimeInterval = CameraViewController.GlobalConstants.animateInDuration
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    strokeColor = UIColor.white.withAlphaComponent(Constants.alphaValue).cgColor
    lineWidth = Constants.strokeWidth
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    fillColor = UIColor.clear.cgColor
    path = normalCross.cgPath
  }
  
  
  // Cross shape to represent the exit button from the camera view
  private var normalCross: UIBezierPath {
    let inset: CGFloat = Constants.squareInsetPx
    let newRect = bounds.insetBy(dx: inset, dy: inset)
    let crossPath = UIBezierPath()
    crossPath.move(to: newRect.origin)
    crossPath.addLine(to: CGPoint(x: newRect.maxX, y: newRect.minY))
    crossPath.addLine(to: CGPoint(x: newRect.maxX, y: newRect.maxY))
    crossPath.addLine(to: CGPoint(x: newRect.minX, y: newRect.maxY))
    crossPath.addLine(to: CGPoint(x: newRect.minX, y: newRect.minY))
    return crossPath
  }
  
  
  // When the camera view loads, the square is stroked to animate in
  func animateIn () {
    let animation = CABasicAnimation(keyPath: "strokeEnd")
    animation.fromValue = 0.0
    animation.toValue = 1.0
    animation.duration = animateInDuration
    animation.isRemovedOnCompletion = true
    add(animation, forKey: "strokeEnd")
  }
}
