//
//  TransitableViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class TransitableViewController: UIViewController {
  
  // MARK: - Constants
  
  struct Constants {
    fileprivate static let TransitionDuration = FoodieGlobal.Constants.DefaultTransitionAnimationDuration
    fileprivate static let TransitionAlpha = FoodieGlobal.Constants.DefaultTransitionUnderVCAlpha
    fileprivate static let DragVelocityToDismiss: CGFloat = 800.0
  }
  
  
  // MARK: - Private Instance Variables
  
  var dragGestureRecognizer: UIPanGestureRecognizer?
  var dismissDirection: TransitionAnimator.Direction?
  var dragDirectionIsFixed: Bool = true
  var animator: TransitionAnimator?
  var interactor: PercentInteractor?
  
  
  
  // MARK: - Public Instance Functions
  
  @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
    guard let dismissDirection = dismissDirection else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("No Dimiss Direction even tho dragGestureRecognizer is set")
      }
      return
    }
    
    guard let animator = animator else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("No Animator even tho dragGestureRecognizer is set")
      }
      return
    }
    
    guard let interactor = interactor else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("No Interactor even tho dragGestureRecognizer is set")
      }
      return
    }
    
    let gestureTranslation = panGesture.translation(in: view)
    let gestureVelocity = panGesture.velocity(in: view)
    var frameTranslation = gestureTranslation
    var frameVelocity = gestureVelocity
    var directionalVelocity: CGFloat
    var remainingTranslation: CGFloat
    var progress: CGFloat
    
    switch dismissDirection {
    case .up:
      let directionalTranslation = min(gestureTranslation.y, 0.0)
      directionalVelocity = min(gestureVelocity.y, 0.0)
      remainingTranslation = view.frame.origin.y
      progress = 1 - remainingTranslation/view.bounds.height
      
      if dragDirectionIsFixed {
        frameTranslation = CGPoint(x: 0.0, y: directionalTranslation)
        frameVelocity = CGPoint(x: 0.0, y: gestureVelocity.y)
      }
      
    case .down:
      let directionalTranslation = max(gestureTranslation.y, 0.0)
      directionalVelocity = max(gestureVelocity.y, 0.0)
      remainingTranslation = view.bounds.height - view.frame.origin.y
      progress = 1 - remainingTranslation/view.bounds.height
      
      if dragDirectionIsFixed {
        frameTranslation = CGPoint(x: 0.0, y: directionalTranslation)
        frameVelocity = CGPoint(x: 0.0, y: gestureVelocity.y)
      }
      
    case .left:
      let directionalTranslation = min(gestureTranslation.x, 0.0)
      directionalVelocity = min(gestureVelocity.x, 0.0)
      remainingTranslation = view.frame.origin.x
      progress = 1 - remainingTranslation/view.bounds.width
      
      if dragDirectionIsFixed {
        frameTranslation = CGPoint(x: directionalTranslation, y: 0.0)
        frameVelocity = CGPoint(x: gestureVelocity.x, y: 0.0)
      }
      
    case .right:
      let directionalTranslation = max(gestureTranslation.x, 0.0)
      directionalVelocity = max(gestureVelocity.x, 0.0)
      remainingTranslation = view.bounds.width - view.frame.origin.x
      progress = 1 - remainingTranslation/view.bounds.width
      
      if dragDirectionIsFixed {
        frameTranslation = CGPoint(x: directionalTranslation, y: 0.0)
        frameVelocity = CGPoint(x: gestureVelocity.x, y: 0.0)
      }
      
    case .stay:
      CCLog.fatal("None not allowed for draggable dismiss")
    }

    switch panGesture.state {
    case .began:
      interactor.hasStarted = true
      animator.dismissDirection = .stay
      if let navigationController = navigationController {
        navigationController.popViewController(animated: true)
      } else {
        dismiss(animated: true, completion: nil)
      }

    case .changed:
      view.frame.origin = frameTranslation
      interactor.update(CGFloat(progress))
      
    case .ended:
      if directionalVelocity >= Constants.DragVelocityToDismiss {
        let duration = TimeInterval(1.5*remainingTranslation/directionalVelocity)
        let endPoint = CGPoint(x: self.view.frame.origin.x + (CGFloat(duration) * frameVelocity.x),
                               y: self.view.frame.origin.y + (CGFloat(duration) * frameVelocity.y))
        interactor.finish()
        UIView.animate(withDuration: duration, delay: TimeInterval(0.0), options: [.curveEaseOut], animations: {
          self.view.frame.origin = endPoint
        })
//        // The following code only works in iOS 11 but not on iOS 10. Still a mystery...
//        UIView.animate(withDuration: duration, animations: {
//          self.view.frame.origin = endPoint
//        }, completion: { isCompleted in
//          CCLog.verbose("PanGesture.State End Animation Completed")
//          //interactor.finish()
//        })
        break
        
      } else {
        fallthrough
      }
      
    default:
      interactor.hasStarted = false
      interactor.cancel()
      animator.dismissDirection = dismissDirection
      UIView.animate(withDuration: 0.2, animations: {
        self.view.frame.origin = CGPoint.zero
      }, completion: { isCompleted in
        self.view.frame.origin = CGPoint.zero
      })
    }
  }
  
  
  // This function is the parent TVC setting transition for self
  func setTransition(presentTowards presentDirection: TransitionAnimator.Direction,
                     dismissTowards dismissDirection: TransitionAnimator.Direction,
                     dismissIsDraggable: Bool = false,
                     dragDirectionIsFixed: Bool = true,
                     targetAlpha: CGFloat = Constants.TransitionAlpha,
                     duration: TimeInterval = Constants.TransitionDuration) {
    
    let transitionAnimator = TransitionAnimator()
    
    if dismissIsDraggable {
      self.dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
      self.interactor = PercentInteractor()
      
      self.dismissDirection = dismissDirection
      self.dragDirectionIsFixed = dragDirectionIsFixed
    }
    
    transitionAnimator.presentDirection = presentDirection
    transitionAnimator.dismissDirection = dismissDirection
    transitionAnimator.targetAlpha = targetAlpha
    transitionAnimator.duration = duration
    self.animator = transitionAnimator
    self.transitioningDelegate = self
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidLoad")
    if let dragGestureRecognizer = dragGestureRecognizer {
      view.addGestureRecognizer(dragGestureRecognizer)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewWillAppear")
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidAppear")
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewWillDisappear")
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") viewDidDisappear")
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") didReceiveMemoryWarning")
  }
  
  func topViewWillResignActive() {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Will Resign Active")
  }
  
  func topViewDidEnterBackground() {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Did Enter Background")
  }
  
  func topViewWillEnterForeground() {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Will Enter Foreground")
  }
  
  func topViewDidBecomeActive() {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") was top view when application Did Become Active")
  }
  
  deinit {
    CCLog.verbose("\(self.restorationIdentifier != nil ? self.restorationIdentifier! : "") deinit")
  }
}



// MARK: - ViewController Transition Delegate Protocol
extension TransitableViewController: UIViewControllerTransitioningDelegate {
  
  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    animator?.isPresenting = true
    return animator
  }
  
  func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return nil
  }
  
  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    animator?.isPresenting = false
    return animator
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
extension TransitableViewController: UINavigationControllerDelegate {
  
  func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if operation == .push {
      animator?.isPresenting = true
    } else if operation == .pop {
      animator?.isPresenting = false
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
