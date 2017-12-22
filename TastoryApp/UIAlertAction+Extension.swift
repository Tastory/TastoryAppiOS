//
//  UIAlertAction+Extension.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-11.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit

extension UIAlertAction {
  
  // Convenience initializer to support title localization
  convenience init(title: String?, comment: String?, style: UIAlertActionStyle, handler: ((UIAlertAction) -> Swift.Void)? = nil) {
    
    let buttonTitle = NSLocalizedString(title == nil ? "" : title!, comment: comment == nil ? "" : comment!)
    
    self.init(title: buttonTitle, style: style, handler: handler)
  }
}
