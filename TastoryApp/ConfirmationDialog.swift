//
//  ConfirmationDialog.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2017-10-14.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

class ConfirmationDialog {

  struct Constants {
    static let dialogWidth: CGFloat = 300.0
    static let dialogHeight: CGFloat = 350.0
  }

  static func displayStorySelection(to viewController: UIViewController, newStoryHandler: @escaping (UIAlertAction) -> Void, addToCurrentHandler: @escaping (UIAlertAction) -> Void, displayAt: UIView? = nil, popUpControllerDelegate: UIPopoverPresentationControllerDelegate? = nil) {
    // Display Action Sheet to ask user if they want to add this Moment to current Story, or a new one, or Cancel
    // Create a button and associated Callback for adding the Moment to a new Story
    let addToNewButton =
      UIAlertAction(title: "New Story",
                    comment: "Button for adding to a New Story in Save Moment action sheet",
                    style: .default,
                    handler: newStoryHandler)
    // Create a button with associated Callback for adding the Moment to the current Story
    let addToCurrentButton =
      UIAlertAction(title: "Current Story",
                    comment: "Button for adding to a Current Story in Save Moment action sheet",
                    style: .default,
                    handler: addToCurrentHandler)

    // Finally, create the Action Sheet!
    let actionSheet = UIAlertController(title: "Add this Moment to...",
                                        titleComment: "Title for Save Moment action sheet",
                                        message: nil, messageComment: nil,
                                        preferredStyle: .actionSheet)
    actionSheet.addAction(addToNewButton)
    actionSheet.addAction(addToCurrentButton)
    actionSheet.addAlertAction(title: "Cancel",
                               comment: "Action Sheet button for Cancelling Adding a Moment in MarkupImageView",
                               style: .cancel)

    if let popOverController = actionSheet.popoverPresentationController {
      if displayAt == nil {
        // ipad must display this dialog as a popover controller otherwise it will crash
        CCLog.fatal("Ipad can't display story selection dialog without displayAt rect")
      }
      actionSheet.modalPresentationStyle = .popover
      let viewWidth = displayAt!.bounds.width
      let viewHeight = displayAt!.bounds.height

      popOverController.sourceRect = CGRect(x: (viewWidth / 2) - (Constants.dialogWidth/2), y: (viewHeight / 2) - (Constants.dialogHeight / 2), width: Constants.dialogWidth , height: Constants.dialogHeight)
      popOverController.sourceView = displayAt!
      popOverController.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
      popOverController.delegate = popUpControllerDelegate
    }

    viewController.present(actionSheet, animated: true, completion: nil)
  }

  static func showStoryDiscardDialog(to viewController: UIViewController,
                                     message: String = "Are you sure you want to discard and overwrite the current Story?",
                                     title: String = "Discard & Overwrite",
                                     withBlock callback: @escaping ()->Void ) {

    // Create a button and associated Callback for discarding the previous current Story and make a new one
    let discardButton =
      UIKit.UIAlertAction(title: "Discard",
                          comment: "Button to discard current Story in alert dialog box to warn user",
                          style: .destructive) { _ in
                          callback()
    }

    let alertController =
      UIAlertController(title: title,
                        titleComment: "Dialog title to warn user on discard and overwrite",
                        message: message,
                        messageComment: "Dialog message to warn user on discard and overwrite",
                        preferredStyle: .alert)

    alertController.addAction(discardButton)
    alertController.addAlertAction(title: "Cancel",
                                   comment: "Alert Dialog box button to cancel discarding and overwritting of current Story",
                                   style: .cancel)

    // Present the Discard dialog box to the user
    viewController.present(alertController, animated: true, completion: nil)
  }

  static func showConfirmationDialog(to viewController: UIViewController,
                                     message: String,
                                     title: String ,
                                     confirmCaption: String,
                                     confirmHandler: @escaping (UIAlertAction) -> Void) {

    let alertController =
      UIAlertController(title: title,
                        titleComment: "Dialog title to warn user",
                        message: message,
                        messageComment: "Dialog message to warn user",
                        preferredStyle: .alert)

    alertController.addAlertAction(title: confirmCaption,
                                   comment: "Button to confirm action",
                                   style: .destructive,
                                   handler: confirmHandler)
    alertController.addAlertAction(title: "Cancel",
                                   comment: "Alert Dialog box button",
                                   style: .cancel)
    viewController.present(alertController, animated: true, completion: nil)
  }
}
