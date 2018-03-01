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
  var duration: TimeInterval
  var bgOverlayView: UIView?
  
  
  // MARK: - Private Instance Variable
  
  
  // MARK: - Public Static Functions
  
  // Scale is based on width to preserve Aspect Ratio, and Translation is based on midPoints
  static func calculateScaleMove3DTransform(from fromFrame: CGRect, to toFrame: CGRect) -> CATransform3D {
    let xScaleFactor = toFrame.width/fromFrame.width
    let scaleTransform = CATransform3DMakeScale(xScaleFactor, xScaleFactor, 0.999)
    let xTranslation = toFrame.midX - fromFrame.midX
    let yTranslation = toFrame.midY - fromFrame.midY
    let moveTransform = CATransform3DMakeTranslation(xTranslation, yTranslation, 0.0)
    return CATransform3DConcat(scaleTransform, moveTransform)
  }
  
  
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

  
  func remove(_ view: UIView, thenAddTo container: UIView) -> (UIView, CGRect) {
    CCLog.verbose("PopTransitionAnimator Remove from \(container)")
    UIApplication.shared.beginIgnoringInteractionEvents()
    
    let originalFrame = view.frame
    guard let originalSuperview = view.superview else {
      CCLog.fatal("View to remove must have a Superview")
    }
    
    view.removeFromSuperview()
    view.frame = originalSuperview.convert(originalFrame, to: container)
    container.addSubview(view)
  
    return (originalSuperview, originalFrame)
  }
  
  
  func putBack(_ view: UIView, to originalSuperview: UIView, at originalFrame: CGRect) {
    CCLog.verbose("PopTransitionAnimator Put Back to \(originalSuperview)")
    view.removeFromSuperview()
    view.layer.transform = CATransform3DIdentity
    view.frame = originalFrame
    originalSuperview.addSubview(view)
    
    UIApplication.shared.endIgnoringInteractionEvents()
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
    
    // Present Case
    if isPresenting {

      // Remove should always be the first mutating call, as it contains a ignore interaction inside
      let (popFromSuperview, popFromOriginalFrame) = remove(popFromView, thenAddTo: containerView)
      let presentingSubFrame = popFromView.frame
      containerView.bringSubview(toFront: popFromView)
      
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
      
      // Down size the Presented View so it'll animate to the expected size
      let presentedSubFrame = toVC.view.frame

      toVC.view.layer.transform = PopTransitionAnimator.calculateScaleMove3DTransform(from: presentedSubFrame, to: presentingSubFrame)
      toVC.view.alpha = 0.0
      containerView.addSubview(toVC.view)
      containerView.bringSubview(toFront: toVC.view)
      
      // Animate everything!
      UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: timingCurve, animations: {
        fromVC.view.alpha = 0.0
        
        if let bgOverlayView = self.bgOverlayView {
          bgOverlayView.alpha = 1.0
        }
        
        let popBiggerTransform = PopTransitionAnimator.calculateScaleMove3DTransform(from: presentingSubFrame, to: presentedSubFrame)
        self.popFromView.layer.transform = popBiggerTransform
        
        toVC.view.layer.transform = CATransform3DIdentity
        toVC.view.alpha = 1.0
      
      }, completion: { _ in

        // Putback should always be the last call, as it contains a end ignore interaction inside
        self.popFromView.isHidden = true  // Hide it so it looks like it's popped out
        self.putBack(self.popFromView, to: popFromSuperview, at: popFromOriginalFrame)
        
        let transitionWasCancelled = transitionContext.transitionWasCancelled  // Get the Bool first, so there wont' be a retain cycle
        transitionContext.completeTransition(!transitionWasCancelled)
      })
    }
    
    // Dismiss Case
    else {
      var presentingSubFrame: CGRect?
      var popToSuperview: UIView?
      var popToOriginalFrame: CGRect?
      
      if !overridePopDismiss {
        // Remove should always be the first mutating call, as it contains a semaphore inside
        let (popFromSuperview, popFromOriginalFrame) = remove(popFromView, thenAddTo: containerView)
        containerView.insertSubview(popFromView, belowSubview: fromVC.view)
        
        presentingSubFrame = popFromView.frame
        popToSuperview = popFromSuperview
        popToOriginalFrame = popFromOriginalFrame
        
        let presentedSubFrame = fromVC.view.frame
        popFromView.layer.transform = PopTransitionAnimator.calculateScaleMove3DTransform(from: presentingSubFrame!, to: presentedSubFrame)
        popFromView.isHidden = false
        popFromView.setNeedsDisplay()
      }
      
      // Add the toVC to the correct view order
      toVC.view.alpha = 0.0
      containerView.addSubview(toVC.view)
      
      if let bgOverlayView = self.bgOverlayView {
        containerView.insertSubview(toVC.view, belowSubview: bgOverlayView)
      } else {
        containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
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
          fromVC.view.layer.transform = PopTransitionAnimator.calculateScaleMove3DTransform(from: presentedSubFrame, to: presentingSubFrame!)
          fromVC.view.alpha = 0.0
        }
        
      }, completion: { _ in
        let transitionWasCancelled = transitionContext.transitionWasCancelled  // Get the Bool first, so there wont' be a retain cycle
        
        if !self.overridePopDismiss, !transitionWasCancelled {
          // Putback should always be the last call, as it contains a semaphore inside
          self.putBack(self.popFromView, to: popToSuperview!, at: popToOriginalFrame!)
        }
        
        self.overridePopDismiss = false
        transitionContext.completeTransition(!transitionWasCancelled)
      })
    }
  }
}

