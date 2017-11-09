//
//  PopTransitionAnimator.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

// This is a POP Transition. Not a Drag

class PopTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  
  
  // MARK: - Public Instance Variables
  
  var isPresenting: Bool = true
  var timingCurve: UIViewAnimationOptions = .curveEaseInOut
  var overridePopDismiss: Bool = false
  var popTransformInverted: CATransform3D?
  
  
  
  // MARK: - Private Instance Variable
  
  private var duration: TimeInterval
  private var popFromView: UIView
  
  
  
  // MARK: - Public Instance Functions
  
  init(from popFromView: UIView, transitionFor duration: TimeInterval) {
    self.popFromView = popFromView
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
    popFromView.isHidden = true
    
    if isPresenting {
      // Calculate the Presenting Affine Transform
      let presentingSubFrame = popFromView.superview!.convert(popFromView.frame, to: containerView)
      let presentedSubFrame = toVC.view.frame
      
//      if let overlayVC = toVC as? OverlayViewController, let popToFrame = overlayVC.popToFrame {
//        presentedSubFrame = toVC.view.convert(popToFrame, to: containerView)
//      }
    
      let xScaleFactor = presentingSubFrame.width / presentedSubFrame.width
      
      // We don't need the Y scale, as we want to preserve aspect ratio on iPhone X
      // Only works if we want a center to center transform tho.....
      // let yScaleFactor = presentingSubFrame.height / presentedSubFrame.height
      
      let xTranslation = presentingSubFrame.midX - presentedSubFrame.midX
      let yTranslation = presentingSubFrame.midY - presentedSubFrame.midY
      let scaleTransform = CATransform3DMakeScale(xScaleFactor, xScaleFactor, 0.99)
      let translationTransform = CATransform3DMakeTranslation(xTranslation, yTranslation, 0.0)
      popTransformInverted = CATransform3DConcat(scaleTransform, translationTransform)
      
      toVC.view.layer.transform = popTransformInverted!
      containerView.addSubview(toVC.view)
      containerView.bringSubview(toFront: toVC.view)
      
    } else {
      containerView.addSubview(toVC.view)
      containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
      toVC.view.alpha = 0.0
    }
    
    UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
      if self.isPresenting {
        toVC.view.layer.transform = CATransform3DIdentity
        fromVC.view.alpha = 0.0
      } else {
        if !self.overridePopDismiss {
          guard let popTransformInverted = self.popTransformInverted else {
            CCLog.assert("Expected popTransform Matrix to have been filled during presentation")
            return
          }
          fromVC.view.layer.transform = popTransformInverted
        }
        toVC.view.alpha = 1.0
      }
    }, completion: { _ in
      self.popFromView.isHidden = false
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    })
  }
}

