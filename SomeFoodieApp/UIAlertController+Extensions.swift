//
//  UIAlertController+Extensions.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-08.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

extension UIAlertController {
  
  
  // MARK: - Public Structures Definitions
  struct actionSheetButtons {
    let title: String?
    let comment: String?  // Comments are to help localization
    let style: UIAlertActionStyle
  }
  
  
  // Creates an UIAlertController in alert style that just lets the user click OK to dismiss the dialogue
  // Title is required. Message and Comments are optionals
  static func alertWithOK(title: String,
                          titleComment: String? = nil,
                          message: String? = nil,
                          messageComment: String? = nil) -> UIAlertController {
    
    // Title is a required argument
    let titleLocalized = NSLocalizedString(title, comment: (titleComment == nil ? "" : titleComment!))
    
    // Message is optional
    var messageLocalized: String? = nil
    
    if let messageUnwrapepd = message {
      messageLocalized = NSLocalizedString(messageUnwrapepd, comment: (messageComment == nil ? "" : messageComment!))
    }
    
    let alertController = UIAlertController(title: titleLocalized, message: messageLocalized, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    
    return alertController
  }

  
  // Creates an UIAlertController in alert style that lets user click OK to dismiss, along with another button as a link
  // Title is required. Message and Comments are optionals
  static func alertWithOK(withURL path: String,
                          buttonTitle: String,
                          buttonComment: String? = nil,
                          title: String,
                          titleComment: String? = nil,
                          message: String? = nil,
                          messageComment: String? = nil) -> UIAlertController? {
    
    guard let url = URL(string: path) else {
      DebugPrint.assert("Invalid URL String")
      return nil
    }
    
    let alertController = alertWithOK(title: title,
                                      titleComment: titleComment,
                                      message: message,
                                      messageComment: messageComment)

    // Button title is a required argument
    let buttonLocalized = NSLocalizedString(buttonTitle, comment: (buttonComment == nil ? "" : buttonComment!))
    
    alertController.addAction(UIAlertAction(title: buttonLocalized, style: .default) { action in
        
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    })
    
    return alertController
  }
  
  
  // Creates an UIAlertControler in actionSheet style that gives user multiple options along with Cancel
  static func actionSheetWithCancel(title: String? = nil,
                                    titleComment: String? = nil,
                                    buttons: actionSheetButtons...) {
    
    
  }
}
