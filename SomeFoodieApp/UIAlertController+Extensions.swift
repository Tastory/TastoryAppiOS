//
//  UIAlertController+Extensions.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-08.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
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
                   preferredStyle: UIAlertControllerStyle) {
    
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
  func addAlertAction(title: String?, comment: String?, style: UIAlertActionStyle, handler: ((UIAlertAction) -> Swift.Void)? = nil) {
    let alertAction = UIAlertAction(title: title, comment: comment, style: style, handler: handler)
    self.addAction(alertAction)
  }
}
