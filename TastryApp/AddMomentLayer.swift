//
//  AddMomentLayer.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-25.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class AddMomentLayer: CAShapeLayer {

  private struct Constants {
    static let crossInsetPct: CGFloat = 0.2
    static let cornerRadiusPct: CGFloat = 0.05
  }
  
  var frameRect = CGRect()
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    fillColor = UIColor.clear.cgColor
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    
    let lesserEdgeLength = min(bounds.maxX, bounds.maxY)
    frameRect = CGRect(x: bounds.midX - lesserEdgeLength/2,
                       y: bounds.midY - lesserEdgeLength/2,
                       width: lesserEdgeLength, height: lesserEdgeLength)
    
    let addMomentPath = UIBezierPath()
    addMomentPath.append(addFrame)
    addMomentPath.append(addCross)
    path = addMomentPath.cgPath
  }
  
  private var addCross: UIBezierPath {
    let newRect = frameRect.insetBy(dx: frameRect.width*Constants.crossInsetPct,
                                    dy: frameRect.height*Constants.crossInsetPct)
    let addCrossPath = UIBezierPath()
    addCrossPath.move(to: CGPoint(x: newRect.minX,
                                  y: newRect.midY))
    addCrossPath.addLine(to: CGPoint(x: newRect.maxX,
                                     y: newRect.midY))
    addCrossPath.move(to: CGPoint(x: newRect.midX,
                                  y: newRect.minY))
    addCrossPath.addLine(to: CGPoint(x: newRect.midX,
                                     y: newRect.maxY))
    return addCrossPath
  }
  
  private var addFrame: UIBezierPath {
    return UIBezierPath(roundedRect: frameRect, cornerRadius: frameRect.width*Constants.cornerRadiusPct)
  }
  
}
