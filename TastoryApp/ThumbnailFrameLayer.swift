//
//  ThumbnailFrameLayer.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-05-26.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit

class ThumbnailFrameLayer: CAShapeLayer {
  
  convenience init(frame: CGRect) {
    self.init()
    self.frame = frame
    
    fillColor = UIColor.clear.cgColor
    lineCap = kCALineCapRound
    lineJoin = kCALineJoinRound
    path = UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius).cgPath
  }
}
