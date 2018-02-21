//
//  ActivitySpinner
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-02.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit
import SVProgressHUD

class ActivitySpinner {
  
  var blurEffectView: UIVisualEffectView? = nil
  var activityView: UIActivityIndicatorView? = nil
  var controllerView: UIView? = nil
  
  static func globalInit() {
    SVProgressHUD.setDefaultStyle(.custom)
    SVProgressHUD.setDefaultMaskType(.custom)

    SVProgressHUD.setForegroundColor(FoodieGlobal.Constants.ThemeColor)
    SVProgressHUD.setBackgroundColor(UIColor.clear)
    SVProgressHUD.setBackgroundLayerColor(UIColor.clear)
    
    SVProgressHUD.setFadeInAnimationDuration(0.05)
    SVProgressHUD.setFadeOutAnimationDuration(0.05)
    
    // Text-less Appearance
    SVProgressHUD.setRingThickness(3.0)
    SVProgressHUD.setRingNoTextRadius(15.0)
    
    // Apperance with Text
    SVProgressHUD.setRingRadius(25.0)
    SVProgressHUD.setMinimumSize(CGSize(width: 120.0, height: 120.0))
    SVProgressHUD.setCornerRadius(15.0)
    
    if let font = UIFont(name: "Raleway-SemiBold", size: 12.0) {
      SVProgressHUD.setFont(font)
    } else {
      CCLog.warning("Font Raleway-Medium not found")
    }
  }
  
  static func globalApply(with status: String? = nil, with completion: (() -> Void)? = nil) {
    SVProgressHUD.show(withStatus: status)
    completion?()
  }
  
  static func globalRemove(with completion: (() -> Void)? = nil) {
    SVProgressHUD.dismiss {
      completion?()
    }
  }
  
  init(addTo view: UIView, blurStyle: UIBlurEffectStyle = .regular, spinnerStyle: UIActivityIndicatorViewStyle = .whiteLarge) {
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
    DispatchQueue.main.async {
      guard let view = self.controllerView else {
        CCLog.fatal("controllerView = nil when applying Activity Spinner")
      }

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
