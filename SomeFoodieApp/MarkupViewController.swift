//
//  MarkupViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//
//  This is a reusable (Image/Video) Markup View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  - photoToMarkup:    Photo to be Marked-up. Either this or videoToMarkupURL should be set, not both
//         - videoToMarkupURL: URL of the video to be Marked-up. Either this or photoToMarkup shoudl be set, not both
//  Output - Will save marked-up Moment to user selected Journal, set Current Journal if needed before popping itself and the 
//           Camera View Controller from the View Controller stack. If JournalEntryViewController is not already what's remaining
//           on the stack, will set relevant JournalEntryViewController inputs and push it onto the View Controller stack
//

import UIKit
import AVFoundation


class MarkupViewController: UIViewController {
  
  // MARK: - Public Instance Variables
  var mediaURL: URL?  // TODO: Video related implementations
  var mediaType: FoodieMoment.MediaType?
    
  var avPlayer = AVPlayer()
  var avPlayerLayer = AVPlayerLayer()
  
  
  // MARK: - Private Instance Variables
  var photoView: UIImageView?
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var saveButton: UIButton?
  
  
  // MARK: - IBActions
  @IBAction func exitSwiped(_ sender: UISwipeGestureRecognizer) {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }
  
  
  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    let momentObj = FoodieMoment()
    
    guard (mediaURL != nil) else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected. photoToMarkup is nil")
      return
    }
  
    do {  // TODO: Video related implementations
      // Save the image as the media of the Moment
      try momentObj.setMedia(withPhoto: photo)
      
    } catch let thrown as FoodieMoment.ErrorCode {
      
      switch thrown {
        
      case .setMediaWithPhotoImageNil:
        internalErrorDialog()
        DebugPrint.assert("mediaURL is nil")
        return
        
      case .setMediaWithPhotoJpegRepresentationFailed:
        internalErrorDialog()
        DebugPrint.assert("Caught Moment.setMediaWithPhotoJpegRepresentationFailed")
        return
      }
      
    } catch let thrown {
      internalErrorDialog()
      DebugPrint.assert("Caught unrecognized error: \(thrown.localizedDescription)")
      return
    }
    
    if FoodieJournal.currentJournal != nil {
      // Display Action Sheet to ask user if they want to add this Moment to current Journal, or a new one, or Cancel
      
      // Create a button and associated Callback for adding the Moment to a new Journal
      let addToNewButton = UIAlertAction(title: "New Journal",
                                         comment: "Button for adding to a New Journal in Save Moment action sheet",
                                         style: .default) { action in
        
        weak var weakSelf = self

        // Create a button and associated Callback for discarding the previous current Journal and make a new one
        let discardButton = UIAlertAction(title: "Discard",
                                          comment: "Button to discard current Journal in alert dialogue box to warn user",
                                          style: .destructive) { action in
          
          var currentJournal = FoodieJournal()
          
          // Try to make a new Current Journal without saving the previous
          do {
            if let newCurrent = try FoodieJournal.newCurrentSync(saveCurrent: false) {
              currentJournal = newCurrent
            } else {
              weakSelf?.internalErrorDialog()
              DebugPrint.assert("Cannot create new current Journal in place of existing current Journal")
              return
            }
          }
          catch let thrown as FoodieJournal.ErrorCode {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Caught FoodieJournal.Error from .newCurrentSync(): \(thrown.localizedDescription)")
            return
          }
          catch let thrown {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Caught unrecognized Error: \(thrown.localizedDescription)")
            return
          }
           
          // Just directly add to the current Journal
          currentJournal.add(moment: momentObj)
          //Set JournalEntryVC's workingJournal to this Journal
          
          // Present the Journal Entry view
          if (weakSelf != nil) {
            
            // TODO: Factor out all View Controller creation and presentation? code for state restoration purposes
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalEntryViewController") as! JournalEntryViewController
            viewController.restorationClass = nil
            viewController.workingJournal = currentJournal
            weakSelf!.present(viewController, animated: true)
            
          } else {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("weakSelf became nil. Unable to proceed")
            return
          }
        }
        
        let alertController = UIAlertController(title: "Discard & Overwrite",
                                                titleComment: "Dialog title to warn user on discard and overwrite",
                                                message: "Are you sure you want to discard and overwrite the current Journal?",
                                                messageComment: "Dialog message to warn user on discard and overwrite",
                                                preferredStyle: .alert)
                                          
        alertController.addAction(discardButton)
        alertController.addAlertAction(title: "Cancel",
                                       comment: "Alert Dialog box button to cancel discarding and overwritting of current Journal",
                                       style: .cancel)
         
        // Present the Discard dialog box to the user
        if (weakSelf != nil) {
          weakSelf!.present(alertController, animated: true, completion: nil)
        } else {
          weakSelf?.internalErrorDialog()
          DebugPrint.assert("weakSelf became nil. Unable to proceed")
          return
        }
        
      }
      
      // Create a button with associated Callback for adding the Moment to the current Journal
      let addToCurrentButton = UIAlertAction(title: "Current Journal",
                                             comment: "Button for adding to a Current Journal in Save Moment action sheet",
                                             style: .default) { action in
        
        weak var weakSelf = self  // Do we need weak self here? We do right?
        guard let currentJournal = FoodieJournal.currentJournal else {
          weakSelf?.saveErrorDialogue()
          DebugPrint.assert("nil FoodieJorunal.currentJournal when trying to Add a Moment to Current Journal")
          return
        }
        
        // Just directly add to the current Journal
        currentJournal.add(moment: momentObj)
        // Set the JournalEntryVC's workingJournal to this journal
        
        // Present the Journal Entry view
        if (weakSelf != nil) {

          // TODO: Factor out all View Controller creation and presentation? code for state restoration purposes
          let storyboard = UIStoryboard(name: "Main", bundle: nil)
          let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalEntryViewController") as! JournalEntryViewController
          viewController.restorationClass = nil
          viewController.workingJournal = currentJournal
          weakSelf!.present(viewController, animated: true)
          
        } else {
          DebugPrint.fatal("weakSelf became nil. Unable to proceed")
        }
      }
      
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
      self.present(actionSheet, animated: true, completion: nil)
      
    } else {
      
      // Just directly add to a new Journal
      let currentJournal = FoodieJournal.newCurrent()
      currentJournal.add(moment: momentObj)
      // Set the JournalEntryVC's working Journal to this journal
      
      // TODO: Factor out all View Controller creation and presentation? code for state restoration purposes
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalEntryViewController") as! JournalEntryViewController
      viewController.restorationClass = nil
      viewController.workingJournal = currentJournal
      present(viewController, animated: true)
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  // Generic error dialogue box to the user on internal errors
  private func internalErrorDialog() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when a Markup Image view internal error occured",
                                            message: "An internal error has occured. Please try again",
                                            messageComment: "Alert dialogue message when a Markup Image view internal error occured",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK",
                                   comment: "Button in alert dialogue box for generic MarkupImageView errors",
                                   style: .default)
    self.present(alertController, animated: true, completion: nil)
  }
  
  // Generic error dialogue box to the user on save errors
  private func saveErrorDialogue() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when Markup Image view has problem saving",
                                            message: "Error saving Journal. Please try again",
                                            messageComment: "Alert dialogue message when Markup Image view has problem saving",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK",
                                   comment: "Button in alert dialogue box for MarkupImageView save errors",
                                   style: .default)
    self.present(alertController, animated: true, completion: nil)
  }
  
  // Generic error dialogue box to the user when adding Moments
  private func addErrorDialogue() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when Markup Image view has problem adding a Moment",
                                            message: "Error adding Moment. Please try again",
                                            messageComment: "Alert dialogue message when Markup Image view has problem adding a Moment",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK",
                                   comment: "Button in alert dialogue box for error when adding Moments in MarkupImageView",
                                   style: .default)
    
    self.present(alertController, animated: true, completion: nil)
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    // Only one of photoToMarkup or videoToMarkupURL should be set
    if mediaURL == nil {
        DebugPrint.assert("Both photoToMarkup and videoToMarkupURL not-nil")
    }
 
    // Display the photo
    
    if mediaType == .photo {
        
      photoView = UIImageView(frame: view.bounds)
      view.addSubview(photoView!)
      view.sendSubview(toBack: photoView!)
        
      do{
        let imageData = try Data.init(contentsOf: mediaURL!)
        photoView?.image =   UIImage(data: imageData)

      }catch{
        DebugPrint.assert("Failed to load image from tmp folder")
    }
        
        
    // Loop the video
    } else if mediaType == .video {
      NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer.currentItem, queue: .main) { (_) in
        self.avPlayer.seek(to: kCMTimeZero)
        self.avPlayer.play()
      }

      avPlayer = AVPlayer(url: mediaURL!)
      avPlayerLayer = AVPlayerLayer(player: avPlayer)
      avPlayerLayer.frame = self.view.bounds
      view.layer.addSublayer(avPlayerLayer) // TODO: Need to move this layer to the back, it's covering the Save button
      avPlayer.play() // TODO: The video keeps playing even if one swipes right and exits the Markup View
    
    // No image nor video to work on, Fatal
    } else {
      DebugPrint.fatal("Both photoToMarkup and videoToMarkupURL are nil")
    }
    
  }
}
