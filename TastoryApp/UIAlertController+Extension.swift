//
//  UIAlertController+Extensions.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-08.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

extension UIAlertController {
  
  // MARK: - Intenral Function Definitions
  
  // FUNCTION convinience init
  // Convinience custom initializer to incorporate String localization
  convenience init(title: String?,
                   titleComment: String?,
                   message: String?,
                   messageComment: String?,
                   preferredStyle: UIAlertController.Style) {
    
    var titleLocalized: String? = nil
    var messageLocalized: String? = nil
    
    if let titleUnwrapped = title {
      titleLocalized = NSLocalizedString(titleUnwrapped, comment: (titleComment == nil ? "" : titleComment!))
    }
    
    if let messageUnwrapepd = message {
      messageLocalized = NSLocalizedString(messageUnwrapepd, comment: (messageComment == nil ? "" : messageComment!))
    }
    
    self.init(title: titleLocalized, message: messageLocalized, preferredStyle: preferredStyle)
  }
  
  
  // FUNCTION addAlertAction
  // Consider this a convinience function for adding a UIAlertAction to the Alert Controller
  func addAlertAction(title: String?, comment: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Swift.Void)? = nil) {
    let alertAction = UIAlertAction(title: title, comment: comment, style: style, handler: handler)

    if title != nil {
      alertAction.accessibilityLabel = "dialogButton_" + title!
    }
    
    self.addAction(alertAction)
  }
}
