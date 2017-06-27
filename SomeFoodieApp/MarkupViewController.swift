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
import ImageIO
import AVFoundation


protocol MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?)
}


class MarkupViewController: UIViewController {
  
  // MARK: - Public Instance Variables
  var mediaObj: FoodieMedia?
  var markupReturnDelegate: MarkupReturnDelegate?

  
  // MARK: - Private Instance Variables
  fileprivate var avPlayer: AVQueuePlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  fileprivate var avPlayerLooper: AVPlayerLooper?
  
  fileprivate var videoView: UIView?
  fileprivate var photoView: UIImageView?
  
  fileprivate var thumbnailObject: FoodieMedia?
  fileprivate var mediaObject: FoodieMedia!
  
  fileprivate var mediaWidth: Int?
  fileprivate var mediaAspectRatio: Double?
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var saveButton: UIButton?
  
  
  // MARK: - IBActions
  @IBAction func exitSwiped(_ sender: UISwipeGestureRecognizer) {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }

  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    // TODO: Don't let use click save (Gray it out until Thumbnail creation completed)
    
    // Initializing with Media Object also initialize foodieFileName and mediaType
    let momentObj = FoodieMoment(withState: .objectModified, foodieMedia: mediaObject) // viewDidLoad should have resolved the issue with mediaObj == nil by now)
    
    // Setting the Thumbnail Object also initializes the thumbnailFileName
    momentObj.thumbnailObj = thumbnailObject
    
    // Fill in the width and aspect ratio
    guard let width = mediaWidth else {
      saveErrorDialog()
      DebugPrint.assert("Unexpected. mediaWidth == nil")
      return
    }
    momentObj.width = width
    
    guard let aspectRatio = mediaAspectRatio else {
      saveErrorDialog()
      DebugPrint.assert("Unexpected. mediaAspectRatio == nil")
      return
    }
    momentObj.aspectRatio = aspectRatio
    
    if FoodieJournal.currentJournal != nil {
      // Display Action Sheet to ask user if they want to add this Moment to current Journal, or a new one, or Cancel
      
      // Create a button and associated Callback for adding the Moment to a new Journal
      let addToNewButton = UIAlertAction(title: "New Journal",
                                         comment: "Button for adding to a New Journal in Save Moment action sheet",
                                         style: .default) { action in
        
        weak var weakSelf = self

        // Create a button and associated Callback for discarding the previous current Journal and make a new one
        let discardButton = UIAlertAction(title: "Discard",
                                          comment: "Button to discard current Journal in alert dialog box to warn user",
                                          style: .destructive) { action in
          
          var currentJournal: FoodieJournal!
          
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
           
          // currentJournal.add(moment: momentObj)  // We don't add Moments here, we let the Journal Entry View decide what to do with it
          
          // Returned Markedup-Moment back to Presenting View Controller
          if (weakSelf != nil) {
            weakSelf!.avPlayer?.pause()
            
            guard let delegate = weakSelf!.markupReturnDelegate else {
              weakSelf?.internalErrorDialog()
              DebugPrint.assert("Unexpected. markupReturnDelegate became nil. Unable to proceed")
              return
            }
            delegate.markupComplete(markedupMoment: momentObj, suggestedJournal: currentJournal)
            
          } else {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Unexpected. weakSelf became nil. Unable to proceed")
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
          weakSelf?.saveErrorDialog()
          DebugPrint.assert("nil FoodieJorunal.currentJournal when trying to Add a Moment to Current Journal")
          return
        }
        
        // currentJournal.add(moment: momentObj)  // We don't add Moments here, we let the Journal Entry View decide what to do with it
        
        // Present the Journal Entry view
        if (weakSelf != nil) {
          weakSelf!.avPlayer?.pause()
          
          guard let delegate = weakSelf!.markupReturnDelegate else {
            weakSelf?.internalErrorDialog()
            DebugPrint.assert("Unexpected. markupReturnDelegate became nil. Unable to proceed")
            return
          }
          delegate.markupComplete(markedupMoment: momentObj, suggestedJournal: currentJournal)
          
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
      
      // Create a new Current Journal
      let currentJournal = FoodieJournal.newCurrent()
      // currentJournal.add(moment: momentObj)  // We don't add Moments here, we let the Journal Entry View decide what to do with it
      
      avPlayer?.pause()
      
      guard let delegate = markupReturnDelegate else {
        internalErrorDialog()
        DebugPrint.assert("Unexpected. markupReturnDelegate became nil. Unable to proceed")
        return
      }
      delegate.markupComplete(markedupMoment: momentObj, suggestedJournal: currentJournal)
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  // Generic error dialog box to the user on internal errors
  func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Markup Image view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Markup Image view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic MarkupImageView errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Generic error dialog box to the user when displaying photo or video
  fileprivate func displayErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem displaying photo or video",
                                              message: "Error displaying media. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem displaying photo or video",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for error when displaying photo or video in MarkupImageView",
                                     style: .default)
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Generic error dialog box to the user on save errors
  fileprivate func saveErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem saving",
                                              message: "Error saving Journal. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem saving",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for MarkupImageView save errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Generic error dialog box to the user when adding Moments
  fileprivate func addErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem adding a Moment",
                                              message: "Error adding Moment. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem adding a Moment",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for error when adding Moments in MarkupImageView",
                                     style: .default)
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if mediaObj == nil {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, mediaObj == nil ")
      return
    } else {
      mediaObject = mediaObj!
    }
    
    guard let mediaType = mediaObject.mediaType else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, mediaType == nil")
      return
    }
    
    // Display the photo
    if mediaType == .photo {
        
      photoView = UIImageView(frame: view.bounds)
      
      guard let imageView = photoView else {
        displayErrorDialog()
        DebugPrint.assert("photoView = UIImageView(frame: _) failed")
        return
      }
      
      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      view.addSubview(imageView)
      view.sendSubview(toBack: imageView)
      imageView.image = UIImage(data: imageBuffer)
      
    // Loop the video
    } else if mediaType == .video {
      
      guard let videoURL = mediaObject.videoLocalBufferUrl else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.videoLocalBufferUrl == nil")
        return
      }

      avPlayer = AVQueuePlayer()
      avPlayerLayer = AVPlayerLayer(player: avPlayer)
      avPlayerLayer!.frame = self.view.bounds
      avPlayerItem = AVPlayerItem(url: videoURL)
      avPlayerLooper = AVPlayerLooper(player: avPlayer!, templateItem: avPlayerItem!)
      
      videoView = UIView(frame: self.view.bounds)
      videoView!.layer.addSublayer(avPlayerLayer!)
      view.addSubview(videoView!)
      view.sendSubview(toBack: videoView!)
      avPlayer!.play() // TODO: There is some lag with a blank white screen before video starts playing...
      
    
    // No image nor video to work on, Fatal
    } else {
      DebugPrint.fatal("Both photoToMarkup and videoToMarkupURL are nil")
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {

    // Obtain thumbnail, width and aspect ratio ahead of time once view is already loaded
    let thumbnailCgImage: CGImage!
    
    // Need to decide what image to set as thumbnail
    switch mediaObject.mediaType! {
    case .photo:
      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        internalErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      guard let imageSource = CGImageSourceCreateWithData(imageBuffer as CFData, nil) else {
        internalErrorDialog()
        DebugPrint.assert("CGImageSourceCreateWithData() failed")
        return
      }
      
      let options = [
        kCGImageSourceThumbnailMaxPixelSize as String : FoodieConstants.thumbnailPixels as NSNumber,
        kCGImageSourceCreateThumbnailFromImageAlways as String : true as NSNumber,
        kCGImageSourceCreateThumbnailWithTransform as String: true as NSNumber
      ]
      thumbnailCgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)  // Assuming either portrait or square
      
      // Get the width and aspect ratio while at it
      let imageCount = CGImageSourceGetCount(imageSource)
      
      if imageCount != 1 {
        internalErrorDialog()
        DebugPrint.assert("Image Source Count not 1")
        return
      }
      
      guard let imageProperties = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String : AnyObject]) else {
        internalErrorDialog()
        DebugPrint.assert("CGImageSourceCopyPropertiesAtIndex failed to get Dictionary of image properties")
        return
      }
      
      if let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? Int {
        mediaWidth = pixelWidth
      } else {
        internalErrorDialog()
        DebugPrint.assert("Image property with index kCGImagePropertyPixelWidth did not return valid Integer value")
        return
      }
      
      if let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? Int {
        mediaAspectRatio = Double(mediaWidth!)/Double(pixelHeight)
      } else {
        internalErrorDialog()
        DebugPrint.assert("Image property with index kCGImagePropertyPixelHeight did not return valid Integer value")
        return
      }
      
    case .video:      // TODO: Allow user to change timeframe in video to base Thumbnail on
      guard let videoUrl = mediaObject.videoLocalBufferUrl else {
        internalErrorDialog()
        DebugPrint.assert("Unexpected, videoLocalBufferUrl == nil")
        return
      }
      
      let asset = AVURLAsset(url: videoUrl)
      let imgGenerator = AVAssetImageGenerator(asset: asset)
      
      imgGenerator.maximumSize = CGSize(width: FoodieConstants.thumbnailPixels, height: FoodieConstants.thumbnailPixels)  // Assuming either portrait or square
      imgGenerator.appliesPreferredTrackTransform = true
      
      do {
        thumbnailCgImage = try imgGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
      } catch {
        internalErrorDialog()
        DebugPrint.assert("AVAssetImageGenerator.copyCGImage failed with error: \(error.localizedDescription)")
        return
      }
      
      let avTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
      
      if avTracks.count != 1 {
        internalErrorDialog()
        DebugPrint.assert("There isn't exactly 1 video track for the AVURLAsset")
        return
      }
      
      let videoSize = avTracks[0].naturalSize
      mediaWidth = Int(videoSize.width)
      mediaAspectRatio = Double(videoSize.width/videoSize.height)
      
      //DebugPrint.verbose("Media width: \(videoSize.width) height: \(videoSize.height). Thumbnail width: \(thumbnailCgImage.width) height: \(thumbnailCgImage.height)")
    }
    
    // Create a Thumbnail Media with file name based on the original file name of the Media
    guard let foodieFileName = mediaObject.foodieFileName else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected. mediaObject.foodieFileName = nil")
      return
    }
    
    thumbnailObject = FoodieMedia(withState: .objectModified, fileName: FoodieFile.thumbnailFileName(originalFileName: foodieFileName), type: .photo)
    thumbnailObject!.imageMemoryBuffer = UIImageJPEGRepresentation(UIImage(cgImage: thumbnailCgImage), CGFloat(FoodieConstants.jpegCompressionQuality))
    //CGImageRelease(thumbnailCgImage)
  }
}
