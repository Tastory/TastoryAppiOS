//
//  MarkupViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

class MarkupViewController: UIViewController {
  
  
  // MARK: - Public Instance Variables
  var photoToMarkup: UIImage?
  var videoToMarkupURL: URL?  // TODO: Video related implementations
  
  var avPlayer = AVPlayer()
  var avPlayerLayer = AVPlayerLayer()
  
  
  // MARK: - Private Instance Variables
  var photoView: UIImageView?
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var saveButton: UIButton?
  
  
  // MARK: - IBActions
  @IBAction func unwindToMarkupImage(segue: UIStoryboardSegue) {
    // Nothing for now
  }
  
  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    let momentObj = FoodieMoment()
    
    guard let photo = photoToMarkup else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected. photoToMarkup is nil")
      return
    }
  
    do {  // TODO: Video related implementations
      // Save the image as the media of the Moment
      try momentObj.setMedia(withPhoto: photo)
      
    } catch let thrown as FoodieError {
      
      switch thrown.error {
        
      case FoodieError.Code.Moment.setMediaWithPhotoImageNil.rawValue:
        internalErrorDialog()
        DebugPrint.assert("Caught Moment.setMediaWithPhotoImageNil")
        return
        
      case FoodieError.Code.Moment.setMediaWithPhotoJpegRepresentationFailed.rawValue:
        internalErrorDialog()
        DebugPrint.assert("Caught Moment.setMediaWithPhotoJpegRepresentationFailed")
        return
      
      default:
        internalErrorDialog()
        DebugPrint.assert("Caught unrecognized Error: \(thrown.localizedDescription)")
        return
      }
      
    } catch let thrown {
      internalErrorDialog()
      DebugPrint.assert(thrown.localizedDescription)
      return
    }
    
// TODO: Implement with Markup and Scrape features
//    momentObj.markup
//    momentObj.tags
//    
// TODO: Implement along with User Login
//    momentObj.author
//    
// TODO: Implement along with Foursquare integration
//    momentObj.eatery
//    momentObj.categories
//    momentObj.type
//    momentObj.attribute
//    
// TODO: Impelemnt with display views
//    momentObj.views
//    momentObj.clickthroughs
    
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
          catch let thrown as FoodieError {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Caught FoodieError.Journal from .newCurrentSync(): \(thrown.localizedDescription)")
            return
          }
          catch let thrown {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Caught unrecognized Error: \(thrown.localizedDescription)")
            return
          }
           
          // Just directly add to the current Journal
          currentJournal.add(moment: momentObj)
          FoodieJournal.editingJournal = currentJournal
          
          // Segue to the Journal Entry view
          if (weakSelf != nil) {
            weakSelf!.performSegue(withIdentifier: "toJournalEntry", sender: currentJournal)
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
        FoodieJournal.editingJournal = currentJournal
        
        // Segue to the Journal Entry view
        if (weakSelf != nil) {
          weakSelf!.performSegue(withIdentifier: "toJournalEntry", sender: currentJournal)
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
      FoodieJournal.editingJournal = currentJournal
      
      // Segue to the Journal Entry view
      performSegue(withIdentifier: "toJournalEntry", sender: currentJournal)
    }
  }
  
  
  // MARK: - Class Private Functions
  
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
    
    // Display the photo
    if let photo = photoToMarkup {
      photoView = UIImageView(frame: view.bounds)
      view.addSubview(photoView!)
      view.sendSubview(toBack: photoView!)
      photoView?.image = photo
      
    // Loop the video
    } else if let videoURL = videoToMarkupURL {
      NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer.currentItem, queue: .main) { (_) in
        self.avPlayer.seek(to: kCMTimeZero)
        self.avPlayer.play()
      }
      
      avPlayer = AVPlayer(url: videoURL)
      avPlayerLayer = AVPlayerLayer(player: avPlayer)
      avPlayerLayer.frame = self.view.bounds
      view.layer.addSublayer(avPlayerLayer) // TODO: Need to move this layer to the back, it's covering the Save button
      avPlayer.play() // TODO: The video keeps playing even if one swipes right and exits the Markup View
    }
  }
}
