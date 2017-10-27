//
//  AddStorySelector.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-10-14.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class StorySelector {

  static func displayStorySelection(to viewController: UIViewController, newStoryHandler: @escaping (UIAlertAction) -> Void, addToCurrentHandler: @escaping (UIAlertAction) -> Void) {
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
    viewController.present(actionSheet, animated: true, completion: nil)
  }

  static func showStoryDiscardDialog(to viewController: UIViewController, withBlock callback: @escaping SimpleErrorBlock) {

    guard let story = FoodieStory.currentStory else {
      AlertDialog.standardPresent(from: viewController, title: .genericDeleteError, message: .internalTryAgain)
      CCLog.fatal("Discard current Story but no current Story")
    }

    // Create a button and associated Callback for discarding the previous current Story and make a new one
    let discardButton =
      UIKit.UIAlertAction(title: "Discard",
                          comment: "Button to discard current Story in alert dialog box to warn user",
                          style: .destructive) { action in

                            // If a previous Save is stuck because of whatever reason (slow network, etc). This coming Delete will never go thru... And will clog everything there-after. So whack the entire local just in case regardless...
                            FoodieObject.deleteAll(from: .draft) { error in
                              if let error = error {
                                CCLog.warning("Deleting All Drafts resulted in Error - \(error.localizedDescription)")
                                callback(error)
                              }

                              // Delete all traces of this unPosted Story
                              _ = story.deleteRecursive(from: .both, type: .draft) { error in
                                if let error = error {
                                  CCLog.warning("Deleting Story resulted in Error - \(error.localizedDescription)")
                                }
                              }
                            }

                            FoodieStory.removeCurrent()
                            callback(nil)
    }

    let alertController =
      UIAlertController(title: "Discard & Overwrite",
                        titleComment: "Dialog title to warn user on discard and overwrite",
                        message: "Are you sure you want to discard and overwrite the current Story?",
                        messageComment: "Dialog message to warn user on discard and overwrite",
                        preferredStyle: .alert)

    alertController.addAction(discardButton)
    alertController.addAlertAction(title: "Cancel",
                                   comment: "Alert Dialog box button to cancel discarding and overwritting of current Story",
                                   style: .cancel)

    // Present the Discard dialog box to the user
    viewController.present(alertController, animated: true, completion: nil)
  }
}
