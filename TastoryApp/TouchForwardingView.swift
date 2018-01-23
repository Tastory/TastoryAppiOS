//
//  TouchForwardingView.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

final class TouchForwardingView: UIView {
  
  final var passthroughViews: [UIView] = []
  final var touchBlock: (() -> Void)?
  
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hitView = super.hitTest(point, with: event) else { return nil }
    guard hitView == self else { return hitView }
    
    touchBlock?()
    
    for passthroughView in passthroughViews {
      let point = convert(point, to: passthroughView)
      if let passthroughHitView = passthroughView.hitTest(point, with: event) {
        return passthroughHitView
      }
    }
    return nil
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = true
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = true
  }
}
