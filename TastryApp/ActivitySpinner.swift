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
    DispatchQueue.main.async {
      let blurEffect = UIBlurEffect(style: blurStyle)
      self.blurEffectView = UIVisualEffectView(effect: blurEffect)
      view.addSubview(self.blurEffectView!)
      view.sendSubview(toBack: self.blurEffectView!)
      self.blurEffectView!.isHidden = true
      self.activityView = UIActivityIndicatorView(activityIndicatorStyle: spinnerStyle)
      view.addSubview(self.activityView!)
      self.activityView!.isHidden = true
      view.sendSubview(toBack: self.activityView!)
      self.controllerView = view
    }
  }
  
  func apply(below subview: UIView? = nil, with completion: (() -> Void)? = nil) {
    DispatchQueue.main.async {
      guard let view = self.controllerView else {
        CCLog.fatal("controllerView = nil when applying Activity Spinner")
      }
      
      if let blurEffectView = self.blurEffectView {
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let subview = subview {
          view.insertSubview(blurEffectView, belowSubview: subview)
        } else {
          view.bringSubview(toFront: blurEffectView)
        }
        blurEffectView.isHidden = false
      }
      
      if let activityView = self.activityView {
        activityView.center = view.center
        
        if let subview = subview {
          view.insertSubview(activityView, belowSubview: subview)
        } else {
          view.bringSubview(toFront: activityView)
        }
        activityView.isHidden = false
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
        blurEffectView.isHidden = true
      }
      if let activityView = self.activityView {
        activityView.stopAnimating()
        view.sendSubview(toBack: activityView)
        activityView.isHidden = true
      }
      completion?()
    }
  }
}
