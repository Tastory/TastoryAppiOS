//
//  CameraButton.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-27.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import SwiftyCam

class CameraButton: SwiftyCamButton {
  
  private struct CameraButtonConstants {
    //static let buttonRadius = 25.0
  }
  
  override func draw(_ rect: CGRect) {
    
    super.draw(rect)
    
    // Drawing code
    let buttonRadius = min(bounds.size.width-5, bounds.size.height-5)/2
    let buttonCenter = CGPoint(x: bounds.midX, y: bounds.midY)
    let path = UIBezierPath(arcCenter: buttonCenter,
                            radius: buttonRadius,
                            startAngle: 0,
                            endAngle: CGFloat(2*M_PI),
                            clockwise: true)
    
    path.close()
    UIColor.white.withAlphaComponent(0.0).setFill()
    UIColor.white.setStroke()
    path.lineWidth = 2.0
    path.fill()
    path.stroke()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
  }
}
