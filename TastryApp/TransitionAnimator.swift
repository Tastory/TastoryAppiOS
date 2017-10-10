//
//  TransitionAnimator.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class TransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  
  // MARK: - Types & Enumerations
  enum Direction {
    case up
    case down
    case left
    case right
    case stay
  }
  
  
  // MARK: - Constants
  struct Constants {
    fileprivate static let TransitionDuration = FoodieGlobal.Constants.DefaultTransitionAnimationDuration
    fileprivate static let TransitionAlpha = FoodieGlobal.Constants.DefaultTransitionUnderVCAlpha
  }
  
  
  // MARK: - Public Instance Variables
  var presentDirection: Direction?
  var dismissDirection: Direction?
  var targetAlpha = Constants.TransitionAlpha
  var isPresenting: Bool = true
  var duration = Constants.TransitionDuration
  
  
  // MARK: - Public Instance Functions
  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
  }
  
  
  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    
    guard let fromVC = transitionContext.viewController(forKey: .from), let toVC = transitionContext.viewController(forKey: .to) else {
      CCLog.assert("No From ViewController and/or To ViewController")
      return
    }
    
    guard let presentDirection = presentDirection else {
      CCLog.assert("No Direction specified for Presentation Transition")
      return
    }
    
    guard let dismissDirection = dismissDirection else {
      CCLog.assert("No Direction specified for Dismiss Transition")
      return
    }
    
    let containerView = transitionContext.containerView
    let screenBounds = UIScreen.main.bounds
    var startOrigin = CGPoint(x: 0.0, y: 0.0)
    var endOrigin = CGPoint(x: 0.0, y: 0.0)
    var finalAlpha = CGFloat(1.0)
    var movingView: UIView
    var fadingView: UIView
    var direction: Direction
    
    if isPresenting {
      direction = presentDirection

      switch direction {
      case .up:
        startOrigin = CGPoint(x: 0, y: screenBounds.height)
      case .down:
        startOrigin = CGPoint(x: 0, y: -screenBounds.height)
      case .left:
        startOrigin = CGPoint(x: screenBounds.width, y: 0)
      case .right:
        startOrigin = CGPoint(x: -screenBounds.width, y: 0)
      case .stay:
        break
      }
      
      toVC.view.frame = CGRect(origin: startOrigin, size: screenBounds.size)
      containerView.addSubview(toVC.view)
      containerView.bringSubview(toFront: toVC.view)
      movingView = toVC.view
      fadingView = fromVC.view
      finalAlpha = self.targetAlpha
      
    } else {
      direction = dismissDirection
      
      switch direction {
      case .up:
        endOrigin = CGPoint(x: 0, y: -screenBounds.height)
      case .down:
        endOrigin = CGPoint(x: 0, y: screenBounds.height)
      case .left:
        endOrigin = CGPoint(x: -screenBounds.width, y: 0)
      case .right:
        endOrigin = CGPoint(x: screenBounds.width, y: 0)
      case .stay:
        break
      }

      toVC.view.alpha = self.targetAlpha
      containerView.addSubview(toVC.view)
      containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
      movingView = fromVC.view
      fadingView = toVC.view
    }
    
    let finalFrame = CGRect(origin: endOrigin, size: screenBounds.size)
    
    UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
      movingView.frame = finalFrame
      fadingView.alpha = finalAlpha
    }, completion: { _ in
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    })
  }
}
