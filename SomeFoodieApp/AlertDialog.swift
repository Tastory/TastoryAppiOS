//
//  AlertDialog.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-27.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

struct AlertDialog {
  
  enum StdTitle: String {
    case genericInternalError = "Internal Error"
    case genericNetworkError = "Network Error"
    case genericLocationError = "Location Error"
    case genericSaveError = "Local Save Error"
    case genericRetrieveError = "Local Retrieve Error"
    case genericDeleteError = "Local Delete Error"
  }
  
  
  enum StdMsg: String {
    case internalTryAgain = "Please try again or restart the app and try again"
    case networkTryAgain = "Please check your network connection and try again"
    case locationTryAgain = "Please make sure location permission is 'Allowed' and try again"  // TODO: This should open Privacy Settings
    case saveTryAgain = "Please free up some space and try again"
  }
  
  
  static func present(from vc: UIViewController, title: String, message: String) {
    if vc.presentedViewController == nil {
      let vcTitle = vc.title ?? "untitled ViewController"
      let alertController = UIAlertController(title: title,
                                              titleComment: "Alert dialog title as presented from \(vcTitle)",
                                              message: message,
                                              messageComment: "Alert dialog message as presented from \(vcTitle)",
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box as presented from \(vcTitle)", style: .cancel)
      DispatchQueue.main.async { vc.present(alertController, animated: true, completion: nil) }
    }
  }
  
  
  static func standardPresent(from vc: UIViewController, title: StdTitle, message: StdMsg) {
    AlertDialog.present(from: vc, title: title.rawValue, message: message.rawValue)
  }
}
