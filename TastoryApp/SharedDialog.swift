//
//  SharedDialog.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-03.
//  Copyright © 2018 Tastry. All rights reserved.
//

import Foundation
import UIKit

struct SharedDialog {
  static func showPopUp(url: String, fromVC: UIViewController) {
    let urlActivityItem : NSURL = NSURL(string: url)!

    let activityViewController : UIActivityViewController = UIActivityViewController(
      activityItems: [urlActivityItem], applicationActivities: nil)

    activityViewController.excludedActivityTypes = [
      UIActivityType.postToWeibo,
      UIActivityType.print,
      UIActivityType.assignToContact,
      UIActivityType.saveToCameraRoll,
      UIActivityType.addToReadingList,
      UIActivityType.postToFlickr,
      UIActivityType.postToVimeo,
      UIActivityType.postToTencentWeibo,
      UIActivityType(rawValue: "com.apple.reminders.RemindersEditorExtension"),
      UIActivityType(rawValue: "com.apple.mobilenotes.SharingExtension")
    ]

    fromVC.present(activityViewController, animated: true, completion: nil)
  }
}
