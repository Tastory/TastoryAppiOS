//
//  ThumbnailFrameLayer.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-26.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class ThumbnailFrameLayer: CAShapeLayer {
  
  private struct Constants {
    static let cornerRadiusPct: CGFloat = 0.05
  }
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    fillColor = UIColor.clear.cgColor
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    path = UIBezierPath(roundedRect: frame, cornerRadius: frame.width*Constants.cornerRadiusPct).cgPath
  }
}
