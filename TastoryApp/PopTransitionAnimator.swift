//
//  PopTransitionAnimator.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

// This is a POP Transition. Not a Drag

class PopTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  
  
  // MARK: - Public Instance Variables
  
  var isPresenting: Bool = true
  var timingCurve: UIViewAnimationOptions = .curveEaseInOut
  var overridePopDismiss: Bool = false
  var popFromView: UIView
  var popFromSuperview: UIView?
  var popFromOriginalFrame: CGRect?
  var popSmallerTransform: CATransform3D?
  var duration: TimeInterval
  var bgOverlayView: UIView?
  
  // MARK: - Private Instance Variable

  
  
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
  
  
  // Scale is based on width to preserve Aspect Ratio, and Translation is based on midPoints
  func calculateScaleMove3DTransform(from fromFrame: CGRect, to toFrame: CGRect) -> CATransform3D {
    let xScaleFactor = toFrame.width/fromFrame.width
    let scaleTransform = CATransform3DMakeScale(xScaleFactor, xScaleFactor, 0.999)
    let xTranslation = toFrame.midX - fromFrame.midX
    let yTranslation = toFrame.midY - fromFrame.midY
    let moveTransform = CATransform3DMakeTranslation(xTranslation, yTranslation, 0.0)
    return CATransform3DConcat(scaleTransform, moveTransform)
  }
  
  
  func remove(_ view: UIView, thenAddTo container: UIView) {
    let originalFrame = view.frame
    guard let originalSuperview = view.superview else {
      CCLog.fatal("View to remove must have a Superview")
    }
    view.removeFromSuperview()
    view.frame = originalSuperview.convert(originalFrame, to: container)
    container.addSubview(view)
  }
  
  
  func putBack(_ view: UIView, to originalSuperview: UIView, at originalFrame: CGRect) {
    CCLog.verbose("PopTransitionAnimator Put Back")
    view.removeFromSuperview()
    view.layer.transform = CATransform3DIdentity
    view.frame = originalFrame
    originalSuperview.addSubview(view)
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
    let presentingSubFrame = popFromView.superview!.convert(popFromView.frame, to: containerView)
    popFromSuperview = popFromView.superview!
    popFromOriginalFrame = popFromView.frame
    
    // Printing the Pop From View
//    CCLog.info("isPresenting = \(isPresenting)")
//    CCLog.info("presentingSubFrame originX: \(presentingSubFrame.origin.x), originY: \(presentingSubFrame.origin.y), width: \(presentingSubFrame.width), height: \(presentingSubFrame.height)")
//    CCLog.info("popFromView.frame originX: \(popFromView.frame.origin.x), originY: \(popFromView.frame.origin.y), width: \(popFromView.frame.width), height: \(popFromView.frame.height)")
//    CCLog.info("popFromView.center x: \(popFromView.center.x), y: \(popFromView.center.y)")
    
    // Present Case
    if isPresenting {
      
      // Put a black overlay over the entire container if optioned
      if let bgOverlayView = bgOverlayView {
        bgOverlayView.frame = containerView.bounds
        bgOverlayView.alpha = 0.0
        containerView.addSubview(bgOverlayView)
        containerView.bringSubview(toFront: bgOverlayView)
        
        if let overlayVC = toVC as? OverlayViewController {
          overlayVC.bgOverlayView = bgOverlayView
        }
      }
      
      // Remove the popFromView and place it in the container view for animation, temporarily
      remove(popFromView, thenAddTo: containerView)
      containerView.bringSubview(toFront: popFromView)
      
//      CCLog.info("popFromView after Removal")
//      CCLog.info("popFromView.frame originX: \(popFromView.frame.origin.x), originY: \(popFromView.frame.origin.y), width: \(popFromView.frame.width), height: \(popFromView.frame.height)")
//      CCLog.info("popFromView.center x: \(popFromView.center.x), y: \(popFromView.center.y)")
      
      // Down size the Presented View so it'll animate to the expected size
      let presentedSubFrame = toVC.view.frame
//      if let overlayVC = toVC as? OverlayViewController, let popToFrame = overlayVC.popToFrame {
//        presentedSubFrame = toVC.view.convert(popToFrame, to: containerView)
//      }
      
      popSmallerTransform = calculateScaleMove3DTransform(from: presentedSubFrame, to: presentingSubFrame)
      toVC.view.layer.transform = popSmallerTransform!
      toVC.view.alpha = 0.0
      containerView.addSubview(toVC.view)
      containerView.bringSubview(toFront: toVC.view)
      
      // Animate everything!
      UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
        fromVC.view.alpha = 0.0
        
        if let bgOverlayView = self.bgOverlayView {
          bgOverlayView.alpha = 1.0
        }
        
        let popBiggerTransform = self.calculateScaleMove3DTransform(from: presentingSubFrame, to: presentedSubFrame)
        self.popFromView.layer.transform = popBiggerTransform
        
        toVC.view.layer.transform = CATransform3DIdentity
        toVC.view.alpha = 1.0
      
      }, completion: { _ in
        // Return the popFromView to where it was
        self.putBack(self.popFromView, to: self.popFromSuperview!, at: self.popFromOriginalFrame!)
        self.popFromView.isHidden = true  // Hide it so it looks like it's popped out
        
        let transitionWasCancelled = transitionContext.transitionWasCancelled  // Get the Bool first, so there wont' be a retain cycle
        transitionContext.completeTransition(!transitionWasCancelled)
      })
    }
    
    // Dismiss Case
    else {
      // Add the toVC to the correct view order
      toVC.view.alpha = 0.0
      containerView.addSubview(toVC.view)
      if let bgOverlayView = self.bgOverlayView {
        containerView.insertSubview(toVC.view, belowSubview: bgOverlayView)
      } else {
        containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
      }
      
      if !overridePopDismiss {
        // Remove the popFromView and place it in the container view for animation, temporarily
        remove(popFromView, thenAddTo: containerView)
        containerView.insertSubview(popFromView, belowSubview: fromVC.view)
        
        let presentedSubFrame = fromVC.view.frame
        let popBiggerTransform = calculateScaleMove3DTransform(from: presentingSubFrame, to: presentedSubFrame)
        popFromView.layer.transform = popBiggerTransform
        popFromView.isHidden = false
      }
      
      // Animate everything!
      UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
        toVC.view.alpha = 1.0
        
        if !self.overridePopDismiss {
          if let bgOverlayView = self.bgOverlayView {
            bgOverlayView.alpha = 0.0
          }
          
          self.popFromView.layer.transform = CATransform3DIdentity
          
          let presentedSubFrame = fromVC.view.frame
          self.popSmallerTransform = self.calculateScaleMove3DTransform(from: presentedSubFrame, to: presentingSubFrame)
          fromVC.view.layer.transform = self.popSmallerTransform!
          fromVC.view.alpha = 0.0
        }
        
      }, completion: { _ in
        if !self.overridePopDismiss {
          // Return the popFromView to where it was
          self.putBack(self.popFromView, to: self.popFromSuperview!, at: self.popFromOriginalFrame!)
        }
        let transitionWasCancelled = transitionContext.transitionWasCancelled  // Get the Bool first, so there wont' be a retain cycle
        transitionContext.completeTransition(!transitionWasCancelled)
      })
    }
  }
}

