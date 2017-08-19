//
//  JournalViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit
import AVFoundation
import SafariServices
import Jot

class JournalViewController: UIViewController {
  
  // MARK: - Constants
  struct Constants {
    static let MomentsToBufferAtATime = FoodieConstants.momentsToBufferAtATime
    static let MomentsViewingTimeInterval = 3.0
  }
  
  
  // MARK: - Public Instance Variables
  var viewingJournal: FoodieJournal? {
    didSet {
      fetchSomeMoment(from: 0)
    }
  }
  
  
  // MARK: - Private Instance Variables
  fileprivate let jotViewController = JotViewController()
  fileprivate var avPlayer: AVPlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  fileprivate var photoTimer: Timer?
  fileprivate var currentMoment: FoodieMoment?
  fileprivate var soundOn: Bool = true
  
  
  // Generic error dialog box to the user on internal errors
  func internalErrorDialog() {
    if self.presentedViewController == nil {
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
  }
  
  // Generic error dialog box to the user when displaying photo or video
  fileprivate func displayErrorDialog() {
    if self.presentedViewController == nil {
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
  }
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var videoView: UIView!
  @IBOutlet weak var blurView: UIVisualEffectView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var tapGestureStackView: UIStackView!
  @IBOutlet weak var tapBackwardsWidth: NSLayoutConstraint!
  @IBOutlet weak var soundButton: UIButton!
  
  
  // MARK: - IBActions
  @IBAction func tapForward(_ sender: UITapGestureRecognizer) {
    displayNextMoment()
  }

  @IBAction func tapBackward(_ sender: UITapGestureRecognizer) {
    displayPreviousMoment()
  }
  
  @IBAction func swipeDown(_ sender: UISwipeGestureRecognizer) {
    cleanUpAndDismiss()
  }
  
  @IBAction func swipeUp(_ sender: UISwipeGestureRecognizer) {
    
    guard let journal = viewingJournal else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, viewingJournal = nil")
      return
    }
    
    if let journalLinkString = journal.journalURL, let journalLinkUrl = URL(string: journalLinkString) {
      
      guard let moment = currentMoment else {
        internalErrorDialog()
        DebugPrint.assert("Unexpected currentMoment = nil")
        return
      }
      
      // Stop video if a video is playing. Remove Timers & Observers
      avPlayer!.pause()
      stopVideoTimerAndObservers(for: moment)
      
      let safariViewController = SFSafariViewController(url: journalLinkUrl)
      safariViewController.delegate = self
      
      let transition = CATransition()
      transition.duration = 0.5
      transition.type = kCATransitionPush
      transition.subtype = kCATransitionFromTop
      view.window!.layer.add(transition, forKey: kCATransition)
      
      self.present(safariViewController, animated: false, completion: nil)
    }
  }
  
  @IBAction func soundToggle(_ sender: UIButton) {
    
    guard let playingMoment = currentMoment else {
      // Not playing any moment, Sound button should do nothing and just return
      return
    }
    soundOn = !soundOn
    
    if playingMoment.playSound && soundOn {
      avPlayer?.volume = 1.0
    } else {
      avPlayer?.volume = 0.0
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  fileprivate func fetchSomeMoment(from momentNumber: Int) {
    guard let journal = viewingJournal else {
      DebugPrint.fatal("Unexpected, no Journal being viewed by Journal View Controller")
    }
    
    guard let moments = journal.moments else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, journalmoments = nil")
      return
    }
    
    // Start pre-fetching if Moment array is not empty
    if !moments.isEmpty {
      journal.contentRetrievalRequest(fromMoment: momentNumber, forUpTo: Constants.MomentsToBufferAtATime)
    }
  }
  
  
  fileprivate func displayMoment(_ moment: FoodieMoment) {
    
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
    
    // Keep track of what moment we are displaying
    currentMoment = moment
    
    // Remove Blue Layer and Activity Indicator
    view.sendSubview(toBack: activityIndicator)
    view.sendSubview(toBack: blurView)
    activityIndicator.stopAnimating()
    
    // Try to display the media as by type
    if mediaType == .photo {

      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      photoView.image = UIImage(data: imageBuffer)
      view.insertSubview(photoView, belowSubview: jotViewController.view)

      // Hide the sound button
      soundButton?.isHidden = true
      
      // Create timer for advancing to the next media? // TODO: Should not be a fixed time
      photoTimer = Timer.scheduledTimer(withTimeInterval: Constants.MomentsViewingTimeInterval,
                                        repeats: false) { [weak self] timer in
        self?.displayNextMoment()
      }
      
    } else if mediaType == .video {
      
      guard let videoURL = mediaObject.videoLocalBufferUrl else {
        displayErrorDialog()
        DebugPrint.assert("Unexpected, mediaObject.videoLocalBufferUrl == nil")
        return
      }
      
      DebugPrint.verbose("Playing Video with URL: \(videoURL)")
      
      avPlayerItem = AVPlayerItem(url: videoURL)
      
      // Put a hook in for what to do next after video completes playing
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(displayNextMoment),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: avPlayerItem)
      
      avPlayer!.replaceCurrentItem(with: avPlayerItem)
      view.insertSubview(videoView, belowSubview: jotViewController.view)
      
      // Should we play sound? Should the sound button be visible?
      avPlayer!.volume = 0.0
      
      // Should we show the sound button?
      if moment.playSound {
        soundButton?.isHidden = false
        
        if soundOn {
          avPlayer!.volume = 1.0
        }
      } else {
        soundButton?.isHidden = true
      }
      
      // Finally, let's play the Media
      avPlayer!.play()
      
      // No image nor video to work on, Fatal
    } else {
      DebugPrint.fatal("MediaType neither .photo nor .video")
    }
    
    // See if there are any Markups to Unserialize
    if let markups = moment.markups {
      var jotDictionary = [AnyHashable: Any]()
      var labelDictionary: [NSDictionary]?
      
      for markup in markups {
        
        if !markup.isDataAvailable {
          displayErrorDialog()
          DebugPrint.fatal("Markup not available even tho Moment deemed Loaded")
        }
        
        guard let dataType = markup.dataType else {
          displayErrorDialog()
          DebugPrint.assert("Unexpected markup.dataType = nil")
          return
        }
        
        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          displayErrorDialog()
          DebugPrint.assert("markup.dataType did not actually translate into valid type")
          return
        }
        
        switch markupType {
          
        case .jotLabel:
          guard let labelData = markup.data else {
            displayErrorDialog()
            DebugPrint.assert("Unexpected markup.data = nil when dataType == .jotLabel")
            return
          }
          
          if labelDictionary == nil {
            labelDictionary = [labelData]
          } else {
            labelDictionary!.append(labelData)
          }
          
        case .jotDrawView:
          guard let drawViewDictionary = markup.data else {
            displayErrorDialog()
            DebugPrint.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
            return
          }
          
          jotDictionary[kDrawView] = drawViewDictionary
        }
      }
      
      jotDictionary[kLabels] = labelDictionary
      jotViewController.unserialize(jotDictionary)
    }
  }
  
  
  fileprivate func displayMomentIfLoaded(for moment: FoodieMoment) {
    
    guard let journal = viewingJournal else {
      DebugPrint.fatal("Unexpected, no Journal being viewed by Journal View Controller")
    }
    
    let momentIndex = journal.getIndexOf(moment)
    
    // Fetch this and a few more moments regardless
    fetchSomeMoment(from: momentIndex)
    
    if moment.foodieObject.checkRetrieved(ifFalseSetDelegate: self) {
      if moment.foodieObject.operationState == .objectSynced {
        DispatchQueue.main.async { [weak self] in self?.displayMoment(moment) }
      } else {
        // Seems moment is not available. Move on to the next one
        DebugPrint.error("displayMomentIfLoaded moment.checkRetrieved returned operationState != .objectSynced. Skipping moment index = \(momentIndex)")
        currentMoment = moment
        displayNextMoment()
      }
    } else {
      DebugPrint.verbose("displayMomentIfLoaded: Not yet loaded")
      
      view.insertSubview(blurView, belowSubview: tapGestureStackView)
      view.insertSubview(activityIndicator, belowSubview: tapGestureStackView)
      soundButton.isHidden = true
      activityIndicator.startAnimating()
    }
  }
  
  
  fileprivate func stopVideoTimerAndObservers(for moment: FoodieMoment) {
    avPlayer?.pause()
    photoTimer?.invalidate()
    photoTimer = nil
    NotificationCenter.default.removeObserver(self)
  }
  
  
  fileprivate func cleanUpAndDismiss() {
    // TODO: Clean-up before dismissing
    if let moment = currentMoment {
      stopVideoTimerAndObservers(for: moment)
    }
    jotViewController.clearAll()
    DispatchQueue.main.async { [weak self] in self?.dismiss(animated: true, completion: nil) }
  }
  
  
  // MARK: - Public Instance Functions
  
  // Display the next Moment based on what the current Moment is
  func displayNextMoment() {
    
    guard let journal = viewingJournal else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, viewingJournal = nil")
      return
    }
    
    guard let moments = journal.moments else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, viewingJournal.moments = nil")
      return
    }
    
    guard let moment = currentMoment else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, currentMoment = nil")
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the next moment and display it
    let nextIndex = journal.getIndexOf(moment) + 1
    
    if nextIndex == moments.count {
      cleanUpAndDismiss()
    } else {
      displayMomentIfLoaded(for: moments[nextIndex])
    }
  }
  
  
  // Display the previous Moment based on what the current Moment is
  func displayPreviousMoment() {
    
    guard let journal = viewingJournal else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, viewingJournal = nil")
      return
    }
    
    guard let moments = journal.moments else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, viewingJournal.moments = nil")
      return
    }
    
    guard let moment = currentMoment else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, currentMoment = nil")
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the previous moment is and display it
    let index = journal.getIndexOf(moment)
    
    if index == 0 {
      cleanUpAndDismiss()
    } else {
      displayMomentIfLoaded(for: moments[index-1])
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    avPlayer = AVPlayer()
    avPlayer?.allowsExternalPlayback = false
    avPlayerLayer = AVPlayerLayer(player: avPlayer)
    avPlayerLayer!.frame = self.view.bounds
    videoView!.layer.addSublayer(avPlayerLayer!)
    
    // This section setups the JotViewController with default initial values
    jotViewController.state = JotViewState.disabled
//    jotViewController.delegate = self
//    jotViewController.textColor = UIColor.black
//    jotViewController.font = UIFont.boldSystemFont(ofSize: 64.0)
//    jotViewController.fontSize = 64.0
//    jotViewController.textEditingInsets = UIEdgeInsetsMake(12.0, 6.0, 0.0, 6.0)  // Commenting out because they are causing constraint conflicts. Not sure why these were inherited from the JotDemo Example
//    jotViewController.initialTextInsets = UIEdgeInsetsMake(6.0, 6.0, 6.0, 6.0)  // Commenting out because they are causing constraint conflicts. Not sure why these were inherited from the JotDemo Example
//    jotViewController.fitOriginalFontSizeToViewWidth = true
//    jotViewController.textAlignment = .left
//    jotViewController.drawingColor = UIColor.cyan
    
    addChildViewController(jotViewController)
    view.addSubview(jotViewController.view)
    view.insertSubview(jotViewController.view, belowSubview: tapGestureStackView)
    jotViewController.didMove(toParentViewController: self)
    jotViewController.view.frame = view.bounds
    
    tapBackwardsWidth.constant = UIScreen.main.bounds.width/3.0  // Gotta test this on a different screen size to know if this works
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    // Always display activity indicator and blur layer up front
    view.insertSubview(blurView, belowSubview: tapGestureStackView)
    view.insertSubview(activityIndicator, belowSubview: tapGestureStackView)
    soundButton.isHidden = true
    activityIndicator.startAnimating()
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    guard let journal = viewingJournal else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected viewingJournal = nil")
      return
    }
    
    guard let moments = journal.moments, !moments.isEmpty else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected viewingJournal.moments = nil or empty")
      return
    }
    
    // If a moment was already in play, just display that again. Otherwise try to display the first moment
    if currentMoment == nil {
      currentMoment = moments[0]
    }
    
    displayMomentIfLoaded(for: currentMoment!)
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    DebugPrint.verbose("JournalViewController disappearing")
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    DebugPrint.log("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Foodie Moment Wait On Content Delegate Conformance

extension JournalViewController: FoodieObjectWaitOnRetrieveDelegate {
  
  func retrieved(for object: FoodieObjectDelegate) {
    guard let moment = object as? FoodieMoment else {
      internalErrorDialog()
      DebugPrint.assert("JouranlViewController retrieved() for object is not FoodieMoment")
      return
    }
    DispatchQueue.main.async { [weak self] in self?.displayMoment(moment) }
  }
}


// MARK: - Safari View Controller Did Finish Delegate Conformance

extension JournalViewController: SFSafariViewControllerDelegate {
  
  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    let transition = CATransition()
    transition.duration = 0.5
    transition.type = kCATransitionPush
    transition.subtype = kCATransitionFromBottom
    controller.view.window!.layer.add(transition, forKey: kCATransition)
  }
}
