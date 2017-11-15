//
//  CGRect+Extension.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-11-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

extension CGRect {
  func makeInsetBySubtracting(_ rect: CGRect) -> UIEdgeInsets {
    let topInset = rect.minY - minY
    let leftInset = rect.minX - minX
    let bottomInset = maxY - rect.maxY
    let rightInset = maxX - rect.maxX
    
    if topInset < 0.0 || leftInset < 0.0 || bottomInset < 0.0 || rightInset < 0.0 {
      CCLog.warning("Negative Inset after Subtraction. Top: \(topInset), Left: \(leftInset), Bottom: \(bottomInset), Right: \(rightInset)")
    }
    return UIEdgeInsetsMake(topInset, leftInset, bottomInset, rightInset)
  }
}
