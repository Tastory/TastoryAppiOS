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
  var popTransform: CATransform3D?
  var popFromView: UIView
  
  
  
  // MARK: - Private Instance Variable
  private var bgOverlayView: UIView?
  private var duration: TimeInterval
  
  
  
  // MARK: - Public Instance Functions
  
  init(from popFromView: UIView, withBgOverlay bgOverlay: Bool, transitionFor duration: TimeInterval) {
    self.popFromView = popFromView
    self.duration = duration
    
    if bgOverlay {
      bgOverlayView = UIView()
      bgOverlayView!.backgroundColor = .black
    }
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
      
      let biggerTrasnform = CATransform3DMakeScale(1/xScaleFactor, 1/xScaleFactor, 0.99)
      let backtrackTransform = CATransform3DMakeTranslation(-xTranslation, -yTranslation, 0.0)
      popTransform = CATransform3DConcat(biggerTrasnform, backtrackTransform)
      
      if let bgOverlayView = bgOverlayView {
        bgOverlayView.frame = containerView.bounds
        bgOverlayView.alpha = 0.0
        containerView.addSubview(bgOverlayView)
        containerView.bringSubview(toFront: bgOverlayView)
      }
      
      toVC.view.layer.transform = popTransformInverted!
      containerView.addSubview(toVC.view)
      containerView.bringSubview(toFront: toVC.view)
      
      self.popFromView.isHidden = true
      
    } else {
      toVC.view.alpha = 0.0
      containerView.addSubview(toVC.view)
      containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
      
      if !self.overridePopDismiss {
        guard let popTransform = self.popTransform else {
          CCLog.assert("Expected popTransform Matrix to have been filled during presentation")
          return
        }
        popFromView.isHidden = false
        popFromView.layer.transform = popTransform
      }
    }
    
    UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
      if self.isPresenting {
        if let bgOverlayView = self.bgOverlayView {
          bgOverlayView.alpha = 1.0
        }
        toVC.view.layer.transform = CATransform3DIdentity
        fromVC.view.alpha = 0.0
      } else {
        
        if !self.overridePopDismiss {
          guard let popTransformInverted = self.popTransformInverted else {
            CCLog.assert("Expected popTransform Matrix to have been filled during presentation")
            return
          }
          fromVC.view.layer.transform = popTransformInverted
          fromVC.view.alpha = 0.0
          self.popFromView.layer.transform = CATransform3DIdentity
        }
        
        if let bgOverlayView = self.bgOverlayView {
          bgOverlayView.alpha = 0.0
        }
        toVC.view.alpha = 1.0
      }
    }, completion: { _ in
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    })
  }
}

