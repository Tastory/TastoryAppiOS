//
//  OverlayViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//


import AsyncDisplayKit

class OverlayViewController: ASViewController<ASDisplayNode> {
  
  // MARK: - Constants
  
  struct Constants {
    fileprivate static let SlideTransitionDuration = FoodieGlobal.Constants.DefaultTransitionAnimationDuration
    fileprivate static let PopTransitionDuration = 0.25
    fileprivate static let DragReturnTransitionDuration = 0.7*PopTransitionDuration
    fileprivate static let FailInteractionAnimationDuration = 0.2
    fileprivate static let DragVelocityToDismiss: CGFloat = 800.0
    fileprivate static let DefaultSlideVCGap: CGFloat = 30.0
  }
  
  
  
  // MARK: - Public Instance Variables
  
  var animator: UIViewControllerAnimatedTransitioning?
  var interactor: PercentInteractor?
  var dragGestureRecognizer: UIPanGestureRecognizer?
  var touchPointCenterOffset: CGPoint?
  var bgOverlayView: UIView?
  
  
  // MARK: - Private Instance Variables
  
  private var bgRestorationRequired = false
  
  
  
  // MARK: - Private Instance Functions
  
  @objc private func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
    
    guard let interactor = interactor else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("No Interactor even tho dragGestureRecognizer is set")
      }
      return
    }
    
    let gestureTranslation = panGesture.translation(in: view.superview!)
    let gestureVelocity = panGesture.velocity(in: view.superview!)
    let screenBounds = UIScreen.main.bounds
    
    if let animator = animator as? SlideTransitionAnimator {
      
      var directionalVelocity: CGFloat
      var progress: CGFloat
      
      // This is ever only user for dismiss! So we gotta do opposite below
      switch animator.presentDirection {
      case .down:
        let directionalTranslation = min(gestureTranslation.y, 0.0)
        directionalVelocity = min(gestureVelocity.y, 0.0)
        progress = abs(directionalTranslation)/(screenBounds.height + animator.vcGap)
        
      case .up:
        let directionalTranslation = max(gestureTranslation.y, 0.0)
        directionalVelocity = max(gestureVelocity.y, 0.0)
        progress = abs(directionalTranslation)/(screenBounds.height + animator.vcGap)
        
      case .right:
        let directionalTranslation = min(gestureTranslation.x, 0.0)
        directionalVelocity = min(gestureVelocity.x, 0.0)
        progress = abs(directionalTranslation)/(screenBounds.width + animator.vcGap)
        
      case .left:
        let directionalTranslation = max(gestureTranslation.x, 0.0)
        directionalVelocity = max(gestureVelocity.x, 0.0)
        progress = abs(directionalTranslation)/(screenBounds.width + animator.vcGap)
      }
      
      switch panGesture.state {
      case .began:
        animator.timingCurve = .curveLinear
        interactor.hasStarted = true
        popDismiss(animated: true)

      case .changed:
        interactor.update(progress)
        
      case .ended:
        if directionalVelocity >= Constants.DragVelocityToDismiss {
          interactor.hasStarted = false
          animator.timingCurve = .curveEaseInOut
          interactor.finish()
        } else {
          fallthrough
        }
        
      default:
        interactor.hasStarted = false
        animator.timingCurve = .curveEaseInOut
        interactor.cancel()
      }
    }
    
    else if let animator = animator as? PopTransitionAnimator {
      
      let directionalTranslation = max(gestureTranslation.y, 0.0)
      let directionalVelocity = max(gestureVelocity.y, 0.0)
      let progress = abs(directionalTranslation)/screenBounds.height
 
      switch panGesture.state {
      case .began:
        let panGestureTouchPoint = panGesture.location(in: view.superview!)
        touchPointCenterOffset = CGPoint(x: view.superview!.bounds.midX - panGestureTouchPoint.x, y: view.superview!.bounds.midY - panGestureTouchPoint.y)
        
        interactor.hasStarted = true
        animator.isPresenting = false
        animator.overridePopDismiss = true
        
        popDismiss(animated: true)
        
      case .changed:
        guard let touchPointCenterOffset = touchPointCenterOffset else {
          CCLog.fatal("No Offset between Touch Point and Center for Pan Gesture saved")
        }
        
        // Don't do anything if this is not considered a downwards gesture
        if directionalTranslation > 0 {
          interactor.update(progress)
          
          let dragTransform = CATransform3DMakeTranslation(gestureTranslation.x, gestureTranslation.y, 0.0)
          let scaleFactor = 1 - progress
          let scaleTransform = CATransform3DMakeScale(scaleFactor, scaleFactor, 1.01)
          let anchorTransform = CATransform3DMakeTranslation(touchPointCenterOffset.x*(scaleFactor-1), touchPointCenterOffset.y*(scaleFactor-1), 0.0)
          let totalTransform = CATransform3DConcat(CATransform3DConcat(scaleTransform, anchorTransform), dragTransform)
          view.layer.transform = totalTransform
        }
        
      case .ended:
        if directionalTranslation > 0 && directionalVelocity > Constants.DragVelocityToDismiss {
          self.touchPointCenterOffset = nil
          
          // Remove the popFromView and place it in the container view for animation, temporarily
          let containerSuperview = self.view.superview!
          let presentingView = animator.popFromView
          animator.remove(presentingView, thenAddTo: containerSuperview)
          containerSuperview.insertSubview(presentingView, belowSubview: self.view)
          
          let popSmallerTransform = animator.calculateScaleMove3DTransform(from: containerSuperview.frame, to: presentingView.frame)
          let popToDragTransform = animator.calculateScaleMove3DTransform(from: presentingView.frame, to: self.view.frame)
          presentingView.layer.transform = popToDragTransform
          presentingView.isHidden = false
          
          interactor.finish()
          
          CCLog.verbose("Pop Interaction Ended for \(self.restorationIdentifier != nil ? self.restorationIdentifier! : "")")
          
          UIView.animate(withDuration: Constants.DragReturnTransitionDuration, animations: {
            self.view.layer.transform = popSmallerTransform
            self.view.alpha = 0.0
            presentingView.layer.transform = CATransform3DIdentity
            
          }, completion: { _ in
            // Return the popFromView to where it was
            guard let popFromSuperView = animator.popFromSuperview, let popFromOriginalCenter = animator.popFromOriginalCenter else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                CCLog.assert("Still expected PopFrom original information to be preserved by this point")
              }
              return
            }
            CCLog.verbose("Executing Put Back for \(self.restorationIdentifier != nil ? self.restorationIdentifier! : "")")
            animator.putBack(presentingView, to: popFromSuperView, at: popFromOriginalCenter)
          })
          
          return
        }
        fallthrough
        
      default:
        touchPointCenterOffset = nil
        interactor.hasStarted = false
        animator.overridePopDismiss = false
        
        interactor.cancel()
        
        UIView.animate(withDuration: Constants.FailInteractionAnimationDuration, animations: {
          self.view.layer.transform = CATransform3DIdentity
        })
      }
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  
  func pushPresent(_ viewController: OverlayViewController, animated: Bool) {
    if let mapNavController = navigationController as? MapNavController {
      mapNavController.delegate = viewController
      mapNavController.pushViewController(viewController, animated: animated)
    }
    else if let navigationController = navigationController {
      navigationController.pushViewController(viewController, animated: animated)
    }
    else {
      present(viewController, animated: animated)
    }
  }
  
  
  func popDismiss(animated: Bool) {
    if let navigationController = navigationController {
      navigationController.popViewController(animated: animated)
    }
    else {
      dismiss(animated: animated)
    }
  }
  
  
  func setSlideTransition(presentTowards direction: BasicDirection,
                          withGapSize gapSize: CGFloat = Constants.DefaultSlideVCGap,
                          dismissIsInteractive: Bool,
                          duration: TimeInterval = Constants.SlideTransitionDuration) {
    
    self.animator = SlideTransitionAnimator(presentTowards: direction, withGapSize: gapSize, transitionFor: duration)
    self.navigationController?.delegate = self  // This will usually be nil. The Pusher needs to set the navigationControllerDelegate
    self.transitioningDelegate = self
    
    if dismissIsInteractive {
      self.dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
      self.interactor = PercentInteractor()
    }
  }
  
  
  func setPopTransition(popFrom fromView: UIView,
                        withBgOverlay bgOverlay: Bool,
                        dismissIsInteractive: Bool,
                        duration: TimeInterval = Constants.PopTransitionDuration) {
    
    self.animator = PopTransitionAnimator(from: fromView, withBgOverlay: bgOverlay, transitionFor: duration)
    self.navigationController?.delegate = self  // This will usually be nil. The Pusher needs to set the navigationControllerDelegate
    self.transitioningDelegate = self
    
    if dismissIsInteractive {
      self.dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
      self.interactor = PercentInteractor()
    }
  }
  
  
  func removePopBgOverlay() {
    bgRestorationRequired = true
    if let bgOverlayView = bgOverlayView {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        bgOverlayView.alpha = 0.0
      })
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidLoad")
    if let dragGestureRecognizer = dragGestureRecognizer {
      view.addGestureRecognizer(dragGestureRecognizer)
    }
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewWillAppear")
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    navigationController?.delegate = self
    
    if let bgOverlayView = bgOverlayView, bgRestorationRequired {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        bgOverlayView.alpha = 1.0
      })
    }
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidAppear")
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewWillDisappear")
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidDisappear")
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") didReceiveMemoryWarning")
  }
  
  func topViewWillResignActive() {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Will Resign Active")
  }
  
  func topViewDidEnterBackground() {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Did Enter Background")
  }
  
  func topViewWillEnterForeground() {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Will Enter Foreground")
  }
  
  func topViewDidBecomeActive() {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Did Become Active")
  }
  
  deinit {
    CCLog.debug("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") deinit")
  }
}



// MARK: - ViewController Transition Delegate Protocol
extension OverlayViewController: UIViewControllerTransitioningDelegate {
  
  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if let animator = animator as? SlideTransitionAnimator {
      animator.isPresenting = true
      return animator
    } else if let animator = animator as? PopTransitionAnimator {
      animator.isPresenting = true
      return animator
    }
    return nil
  }
  
  func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return nil
  }
  
  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if let animator = animator as? SlideTransitionAnimator {
      animator.isPresenting = false
      return animator
    } else if let animator = animator as? PopTransitionAnimator {
      animator.isPresenting = false
      return animator
    }
    return nil
  }
  
  func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    if let interactor = interactor {
      return interactor.hasStarted ? interactor : nil
    } else {
      return nil
    }
  }
}



// MARK: - Navigation Controller Transition Delegate Protocol
extension OverlayViewController: UINavigationControllerDelegate {
  
  func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if operation == .push {
      if let animator = animator as? SlideTransitionAnimator {
        animator.isPresenting = true
      } else if let animator = animator as? PopTransitionAnimator {
        animator.isPresenting = true
      }
    } else if operation == .pop {
      if let animator = animator as? SlideTransitionAnimator {
        animator.isPresenting = false
      } else if let animator = animator as? PopTransitionAnimator {
        animator.isPresenting = false
      }
    }
    return animator
  }
  
  func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    if let interactor = interactor {
      return interactor.hasStarted ? interactor : nil
    } else {
      return nil
    }
  }
}
