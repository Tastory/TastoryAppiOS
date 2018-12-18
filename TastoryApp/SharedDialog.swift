//
//  SharedDialog.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-03.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import Foundation
import UIKit

struct SharedDialog {
  static func showPopUp(url: String, fromVC: UIViewController, sender: UIButton) {
    let urlActivityItem : NSURL = NSURL(string: url)!

    let activityViewController : UIActivityViewController = UIActivityViewController(
      activityItems: [urlActivityItem], applicationActivities: nil)

    if let popOverController = activityViewController.popoverPresentationController {
      popOverController.sourceView = sender
      popOverController.sourceRect = sender.bounds
    }

    activityViewController.excludedActivityTypes = [
      UIActivity.ActivityType.postToWeibo,
      UIActivity.ActivityType.print,
      UIActivity.ActivityType.assignToContact,
      UIActivity.ActivityType.saveToCameraRoll,
      UIActivity.ActivityType.addToReadingList,
      UIActivity.ActivityType.postToFlickr,
      UIActivity.ActivityType.postToVimeo,
      UIActivity.ActivityType.postToTencentWeibo,
      UIActivity.ActivityType(rawValue: "com.apple.reminders.RemindersEditorExtension"),
      UIActivity.ActivityType(rawValue: "com.apple.mobilenotes.SharingExtension")
    ]

    fromVC.present(activityViewController, animated: true, completion: nil)
  }
}
