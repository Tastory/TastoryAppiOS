//
//  SlideTransitionAnimator.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class SlideTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

  
  // MARK: - Public Instance Variables
  
  var presentDirection: BasicDirection
  var vcGap: CGFloat
  var duration: TimeInterval
  var isPresenting: Bool = true
  var timingCurve: UIViewAnimationOptions = .curveEaseInOut
  
  
  // MARK: - Public Instance Functions
  init(presentTowards direction: BasicDirection, withGapSize vcGap: CGFloat, transitionFor duration: TimeInterval) {
    self.presentDirection = direction
    self.vcGap = vcGap
    self.duration = duration
    super.init()
  }
  
  
  override init() {
    CCLog.fatal("Initialization with no argument is not allowed")
  }
  
  
  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return duration
  }
  
  
  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    
    guard let fromVC = transitionContext.viewController(forKey: .from), let toVC = transitionContext.viewController(forKey: .to) else {
      CCLog.assert("No From ViewController and/or To ViewController")
      return
    }
    
    let containerView = transitionContext.containerView
    let screenBounds = UIScreen.main.bounds
    var slideVector: CGPoint
    
    switch presentDirection {
    case .up:
      slideVector = CGPoint(x: 0, y: -(screenBounds.height + vcGap))
    case .down:
      slideVector = CGPoint(x: 0, y: screenBounds.height + vcGap)
    case .left:
      slideVector = CGPoint(x: -(screenBounds.width + vcGap), y: 0)
    case .right:
      slideVector = CGPoint(x: screenBounds.width + vcGap, y: 0)
    }
    
    // Reverse direction if Dismissing
    if !isPresenting { slideVector = slideVector.multiplyScalar(-1.0) }

    // To View always starts opposite of Vector direction, off from Origin
    toVC.view.frame = CGRect(origin: slideVector.multiplyScalar(-1.0), size: screenBounds.size)
    containerView.addSubview(toVC.view)
    
    if isPresenting {
      containerView.bringSubview(toFront: toVC.view)
    } else {
      containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
    }
  
    
    UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
      toVC.view.frame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
      fromVC.view.frame = CGRect(origin: slideVector, size: screenBounds.size)
    }, completion: { _ in
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    })
  }
}
