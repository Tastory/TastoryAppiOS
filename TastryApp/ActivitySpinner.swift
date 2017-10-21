//
//  ActivitySpinner
//  TastryApp
//
//  Created by Howard Lee on 2017-10-02.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


class ActivitySpinner {
  
  var blurEffectView: UIVisualEffectView? = nil
  var activityView: UIActivityIndicatorView? = nil
  var controllerView: UIView? = nil
  
  init(addTo view: UIView, blurStyle: UIBlurEffectStyle = .regular, spinnerStyle: UIActivityIndicatorViewStyle = .whiteLarge) {
    let blurEffect = UIBlurEffect(style: blurStyle)
    blurEffectView = UIVisualEffectView(effect: blurEffect)
    view.addSubview(blurEffectView!)
    activityView = UIActivityIndicatorView(activityIndicatorStyle: spinnerStyle)
    view.addSubview(activityView!)
    controllerView = view
  }
  
  func apply(below subview: UIView? = nil, with completion: (() -> Void)? = nil) {
    guard let view = controllerView else {
      CCLog.fatal("controllerView = nil when applying Activity Spinner")
    }
    
    DispatchQueue.main.async {
      if let blurEffectView = self.blurEffectView {
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let subview = subview {
          view.insertSubview(blurEffectView, belowSubview: subview)
        } else {
          view.bringSubview(toFront: blurEffectView)
        }
      }
      
      if let activityView = self.activityView {
        activityView.center = view.center
        
        if let subview = subview {
          view.insertSubview(activityView, belowSubview: subview)
        } else {
          view.bringSubview(toFront: activityView)
        }
        activityView.startAnimating()
      }
      completion?()
    }
  }
  
  func remove(with completion: (() -> Void)? = nil) {
    guard let view = controllerView else {
      CCLog.fatal("controllerView = nil when applying Activity Spinner")
    }
    
    DispatchQueue.main.async {
      if let blurEffectView = self.blurEffectView {
        view.sendSubview(toBack: blurEffectView)
      }
      if let activityView = self.activityView {
        activityView.stopAnimating()
        view.sendSubview(toBack: activityView)
      }
      completion?()
    }
  }
}
