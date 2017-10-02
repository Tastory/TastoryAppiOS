//
//  BlurSpinWait
//  TastryApp
//
//  Created by Howard Lee on 2017-10-02.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class BlurSpinWait {
  
  var blurEffectView: UIVisualEffectView? = nil
  var activityView: UIActivityIndicatorView? = nil
  
  func apply(to view: UIView, blurStyle: UIBlurEffectStyle, spinnerStyle: UIActivityIndicatorViewStyle) {
    DispatchQueue.main.async {
      let blurEffect = UIBlurEffect(style: .light)
      self.blurEffectView = UIVisualEffectView(effect: blurEffect)
      self.blurEffectView!.frame = view.bounds
      self.blurEffectView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(self.blurEffectView!)
      
      self.activityView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
      self.activityView!.center = view.center
      self.activityView!.startAnimating()
      view.addSubview(self.activityView!)
    }
  }
  
  func remove() {
  
    guard let blurEffectView = blurEffectView else {
      CCLog.fatal("blurEffectView = nil")
    }
    
    guard let activityView = activityView else {
      CCLog.fatal("activityView = nil")
    }
    
    DispatchQueue.main.async {
      blurEffectView.removeFromSuperview()
      activityView.removeFromSuperview()
    }
  }
}
