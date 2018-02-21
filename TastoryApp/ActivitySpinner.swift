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
  var activityView: UIView? = nil
  var svProgressHUD: SVProgressHUD? = nil
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
  
  init(addTo view: UIView, blurStyle: UIBlurEffectStyle = .regular, radius: CGFloat = 15.0, thickness: CGFloat = 3.0, color: UIColor = FoodieGlobal.Constants.ThemeColor) {
    
    let blurEffect = UIBlurEffect(style: blurStyle)
    blurEffectView = UIVisualEffectView(effect: blurEffect)
    view.addSubview(self.blurEffectView!)
    blurEffectView!.isHidden = true
    view.sendSubview(toBack: self.blurEffectView!)
    
    svProgressHUD = SVProgressHUD(frame: view.bounds)
    
    svProgressHUD!.defaultStyle = .custom
    svProgressHUD!.defaultMaskType = .custom
    
    svProgressHUD!.foregroundColor = FoodieGlobal.Constants.ThemeColor
    svProgressHUD!.backgroundColor = UIColor.clear
    svProgressHUD!.backgroundLayerColor = UIColor.clear
    
    svProgressHUD!.fadeInAnimationDuration = 0.05
    svProgressHUD!.fadeOutAnimationDuration  = 0.05
    
    svProgressHUD!.ringThickness = thickness
    svProgressHUD!.ringNoTextRadius = radius
    
    activityView = UIView()
    svProgressHUD!.containerView = activityView
    activityView!.addSubview(svProgressHUD!)
    view.addSubview(self.activityView!)
    activityView!.isHidden = true
    view.sendSubview(toBack: self.activityView!)
    
    controllerView = view
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
      
      if let svProgressHUD = self.svProgressHUD, let activityView = self.activityView {
        activityView.frame = view.bounds
        activityView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let subview = subview {
          view.insertSubview(activityView, belowSubview: subview)
        } else {
          view.bringSubview(toFront: activityView)
        }
        activityView.isHidden = false
        svProgressHUD.show()
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
        view.sendSubview(toBack: activityView)
        activityView.isHidden = true
      }
      
      if let svProgressHUD = self.svProgressHUD {
        svProgressHUD.dismiss()
      }
      
      completion?()
    }
  }
}
