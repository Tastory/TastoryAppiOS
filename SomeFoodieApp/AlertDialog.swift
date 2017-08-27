//
//  AlertDialog.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-27.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

struct AlertDialog {
  static func present(from vc: UIViewController, title: String, message: String) {
    if vc.presentedViewController == nil {
      let vcTitle = vc.title ?? "untitled ViewController"
      let alertController = UIAlertController(title: title,
                                              titleComment: "Alert dialog title as presented from \(vcTitle)",
                                              message: message,
                                              messageComment: "Alert dialog message as presented from \(vcTitle)",
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box as presented from \(vcTitle)", style: .cancel)
      vc.present(alertController, animated: true, completion: nil)
    }
  }
}
