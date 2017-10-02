//
//  PassthruStackView.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-05.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class PassthruStackView: UIStackView {

  // This is to make adopted Stackviews to pass interaction event to the view underneath
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    for subview in subviews {
      if !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
        return true
      }
    }
    return false
  }

}
