//
//  EndGestureRecognizer.swift
//  TastoryApp
//
//  Created by Howard Lee on 2018-03-02.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class EndGestureRecognizer: UIGestureRecognizer {

//  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
//    super.touchesBegan(touches, with: event)
//    state = .began
//  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
    state = .ended
  }
}
