//
//  UIGestureDebug.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-21.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

struct UIGestureDebug {

  static func verbose(_ recognizer: UIGestureRecognizer) {
    
    if let _ = recognizer as? UIPanGestureRecognizer {
      print("Pan ", terminator: "")
      
    } else if let _ = recognizer as? UIPinchGestureRecognizer {
      print("Pinch ", terminator: "")
      
    } else if let _ = recognizer as? UISwipeGestureRecognizer {
      print("Swipe ", terminator: "")
      
    } else if let _ = recognizer as? UITapGestureRecognizer {
      print("Tap ", terminator: "")
      
    } else {
      print("Other ", terminator: "")
      
    }
    
    switch recognizer.state {
      
    case UIGestureRecognizerState.began:
      print("gesture began")
      
    case UIGestureRecognizerState.changed:
      print("gesture changed")
      
    case UIGestureRecognizerState.ended:
      print("gesture ended/recognized")
      
    case UIGestureRecognizerState.possible:
      print("gesture possible")
      
    case UIGestureRecognizerState.failed:
      print("gesture failed")
      
    case UIGestureRecognizerState.cancelled:
      print("gesture cancelled")
      
    }
  }
}
