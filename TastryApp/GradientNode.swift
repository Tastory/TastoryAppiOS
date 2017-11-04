//
//  GradientNode.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-11-03.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import AsyncDisplayKit

class GradientNode: ASDisplayNode {
  
  
  // MARK: - Private Instance Variable
  
  private let startUnitPoint: CGPoint
  private let endUnitPoint: CGPoint
  private let colors: [UIColor]
  private let locations: [CGFloat]?
  
  
  
  // MARK: - Public Class Functions
  
  override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled isCancelledBlock: () -> Bool, isRasterizing: Bool) {

    guard let parameters = parameters as? GradientNode else {
      CCLog.assert("Expected type SimpleGradientNode to be returned")
      return
    }

    let context = UIGraphicsGetCurrentContext()!
    context.saveGState()
    context.clip(to: bounds)

    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: parameters.colors.map { $0.cgColor } as CFArray,
                                    locations: parameters.locations) else {
      CCLog.assert("Unable to create CGGradient")
      return
    }

    context.drawLinearGradient(gradient,
                               start: CGPoint(x: bounds.midX, y: bounds.maxY),
                               end: CGPoint(x: bounds.midX, y: bounds.midY),
                               options: []) //CGGradientDrawingOptions.drawsAfterEndLocation)
    context.restoreGState()
  }
  
  
  
  // MARK: - Public Instance Function
  
  init(startingAt startUnitPoint: CGPoint, endingAt endUnitPoint: CGPoint, with colors: [UIColor], for locations: [CGFloat]? = nil) {
    self.startUnitPoint = startUnitPoint
    self.endUnitPoint = endUnitPoint
    self.colors = colors
    self.locations = locations
    
    super.init()
  }
  
  
  override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
    return self
  }
}
