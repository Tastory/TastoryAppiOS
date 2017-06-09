//
//  JournalViewController.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-04-23.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

class JournalViewController: UIViewController {
  
  // MARK: - IBOutlets
  
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var videoView: UIView!
  @IBOutlet weak var blurView: UIVisualEffectView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  
  // MARK: - Public Instance Variables
  var viewingJournal: FoodieJournal? {
    didSet {
      guard let journal = viewingJournal else {
        // viewingJournal just being cleared. Do clean-up?
        return
      }
      
      guard let moments = journal.moments else {
        internalErrorDialog()
        DebugPrint.assert("Unexpected, empty Moment array")
        return
      }
      
      // Start pre-fetching if Moment array is not empty
      if !moments.isEmpty {
        journal.contentRetrievalKickoff(fromMoment: 0, forUpTo: 0)  // TODO: Don't hardcode these values. forUpTo 0 means all.
      }
    }
  }
  
  
  // MARK: - Private Instance Variables
  fileprivate var avPlayer: AVPlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  
  
  // Generic error dialog box to the user on internal errors
  func internalErrorDialog() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when a Journal View internal error occured",
                                            message: "An internal error has occured. Please try again",
                                            messageComment: "Alert dialog message when a Journal View internal error occured",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK",
                                   comment: "Button in alert dialog box for generic JournalView errors",
                                   style: .default)
    self.present(alertController, animated: true, completion: nil)
  }
  
  // Generic error dialog box to the user when displaying photo or video
  fileprivate func displayErrorDialog() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when Journal View has problem displaying photo or video",
                                            message: "Error displaying media. Please try again",
                                            messageComment: "Alert dialog message when Journal View has problem displaying photo or video",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK",
                                   comment: "Button in alert dialog box for error when displaying photo or video in JournalView",
                                   style: .default)
    
    self.present(alertController, animated: true, completion: nil)
  }
  
  
  // MARK: - IBOutlets

  
  
  // MARK: - IBActions

  
  
  // MARK: - Private Instance Functions
  func displayMoment(_ moment: FoodieMoment) {
    
    guard let mediaObject = moment.mediaObj else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, moment.mediaObj == nil ")
      return
    }
    
    guard let mediaType = mediaObject.mediaType else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, mediaObject.mediaType == nil")
      return
    }
    
    if mediaType == .photo {

      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      photoView.image = UIImage(data: imageBuffer)
      view.bringSubview(toFront: photoView)

      // TODO: Create timer for advancing to the next media?
      
    } else if mediaType == .video {
      
      guard let videoURL = mediaObject.videoLocalBufferUrl else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.videoLocalBufferUrl == nil")
        return
      }
      
      avPlayerItem = AVPlayerItem(url: videoURL)
      view.bringSubview(toFront: videoView)
      avPlayer!.play()
      
      // No image nor video to work on, Fatal
    } else {
      DebugPrint.fatal("MediaType neither .photo nor .video")
    }
  }
  
  
  func displayMomentIfLoaded() {
    
  }
  
  
  // MARK: - Public Instance Functions

  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    avPlayer = AVPlayer()
    avPlayerLayer = AVPlayerLayer(player: avPlayer)
    avPlayerLayer!.frame = self.view.bounds
    videoView!.layer.addSublayer(avPlayerLayer!)

    // Always display activity indicator and blur layer up front
    view.bringSubview(toFront: blurView)
    view.bringSubview(toFront: activityIndicator)
    activityIndicator.startAnimating()
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {

  }
}
