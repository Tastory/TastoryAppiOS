//
//  StoryViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import AVFoundation
import SafariServices
import Jot

class StoryViewController: OverlayViewController {
  
  // MARK: - Constants
  
  struct Constants {
    static let MomentsViewingTimeInterval = 5.0
    static let BackgroundGradientBlackAlpha: CGFloat = 0.38
  }
  
  
  
  // MARK: - Public Instance Variables
  
  var draftPreview: Bool = false
  var viewingStory: FoodieStory?
  
  
  
  // MARK: - Private Instance Variables
  private var isAppearanceLayout: Bool = true
  private var isInitialLayout: Bool = true
  
  private let jotViewController = JotViewController()
  private var currentMoment: FoodieMoment?
  private var currentExportPlayer: AVExportPlayer?
  private var localVideoPlayer = AVPlayer()
  private var photoTimer: Timer?
  private var swipeUpGestureRecognizer: UISwipeGestureRecognizer!  // Set by ViewDidLoad
  private var avPlayerLayer: AVPlayerLayer!  // Set by ViewDidLoad
  private var activitySpinner: ActivitySpinner!  // Set by ViewDidLoad
  private var photoTimeRemaining: TimeInterval = 0.0
  private var isPaused: Bool = false
  private var muteObserver: NSKeyValueObservation?
  
  
  
  
  // MARK: - IBOutlets
  
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var videoView: UIView!
  @IBOutlet weak var topStackBackgroundView: UIView!
  @IBOutlet weak var bottomStackBackgroundView: UIView!
  @IBOutlet weak var tapForwardGestureRecognizer: UIView!
  @IBOutlet weak var tapBackwardGestureRecognizer: UIView!
  @IBOutlet weak var venueButton: UIButton!
  @IBOutlet weak var authorButton: UIButton!
  @IBOutlet weak var swipeStack: UIStackView!
  @IBOutlet weak var swipeLabel: UILabel!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var pauseButton: UIButton!
  @IBOutlet weak var soundOnButton: UIButton!
  @IBOutlet weak var soundOffButton: UIButton!
  
  
  
  // MARK: - IBActions
  
  @IBAction func tapForward(_ sender: UITapGestureRecognizer) {
    CCLog.info("User tapped Forward")
    displayNextMoment()
  }

  @IBAction func tapBackward(_ sender: UITapGestureRecognizer) {
    CCLog.info("User tapped Backward")
    displayPreviousMoment()
  }
  
  @IBAction func venueAction(_ sender: UIButton) {
    CCLog.info("User tapped Venue")
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.assert("Unexpected, viewingStory = nil")
      }
      return
    }

    if let venue = story.venue, let foursquareURLString = venue.foursquareURL, let foursquareURL = URL(string: foursquareURLString) {
      pause()
      CCLog.info("Opening Safari View for \(foursquareURLString)")
      let safariViewController = SFSafariViewController(url: foursquareURL)
      safariViewController.delegate = self
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  @IBAction func authorAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ProfileViewController") as? ProfileViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of ProfileViewController Class!!")
      }
      return
    }
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("viewingStory = nil")
      }
      return
    }
    
    guard let author = story.author, author.isDataAvailable else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("viewingStory.author = nil, or isDataAvailable = false")
      }
      return
    }
    
    viewController.user = author
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    
    removePopBgOverlay()
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func pauseAction(_ sender: UIButton) { pause() }
  
  @IBAction func playAction(_ sender: UIButton) {
    CCLog.debug("Calling play()")
    play()
  }
  
  @IBAction func soundOnAction(_ sender: UIButton) {
    AudioControl.unmute()
  }
  
  @IBAction func soundOffAction(_ sender: UIButton) {
    AudioControl.mute()
  }
  
  
  
  // MARK: - Private Instance Functions
  
  private func updateAVMute(audioControl: AudioControl) {
    
    guard let playingMoment = currentMoment else {
      // Not playing any moment, Sound button should do nothing and just return
      return
    }
    
    var avPlayer: AVPlayer
    if let videoPlayer = currentExportPlayer?.avPlayer {
      avPlayer = videoPlayer
    } else {
      avPlayer = localVideoPlayer
    }

    if playingMoment.playSound {
      if !audioControl.isAppMuted {
        avPlayer.volume = 1.0
        soundOnButton.isHidden = true
        soundOffButton.isHidden = false
      } else {
        avPlayer.volume = 0.0
        soundOffButton.isHidden = true
        soundOnButton.isHidden = false
      }
    
  } else {
      avPlayer.volume = 0.0
      soundOffButton.isHidden = true
      soundOnButton.isHidden = true
    }
  }
  
  
  private func displaySwipeStackIfNeeded() {
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.assert("Unexpected, viewingStory = nil")
      }
      return
    }
    
    if let storyLinkString = story.storyURL, URL(string: URL.addHttpIfNeeded(to: storyLinkString)) != nil {
      swipeStack.isHidden = false
    }
  }
  
  
  private func pause() {
    
    if let photoTimer = photoTimer {
      // Photo is 'playing'. Pause photo timer
      photoTimeRemaining = photoTimer.fireDate.timeIntervalSinceNow
      photoTimer.invalidate()
      
    } else {
      
      var avPlayer: AVPlayer
      if let videoPlayer = currentExportPlayer?.avPlayer {
        avPlayer = videoPlayer
      } else {
        avPlayer = localVideoPlayer
      }
      
      // Video is playing. Pause the video
      avPlayer.pause()
    }
    
    // Update the app states
    isPaused = true
    pauseButton.isHidden = true
    playButton.isHidden = false
  }
  
  
  private func play() {
    if let photoTimer = photoTimer {
      
      // Double check that timer is paused before restarting. It's not safe to replace timers otherwise
      if !photoTimer.isValid {
        // Photo is 'paused'. Restart photo timer from where left off
        self.photoTimer = Timer.scheduledTimer(withTimeInterval: photoTimeRemaining,
                                               repeats: false) { [weak self] timer in
                                                self?.displayNextMoment() }
      }
      
    } else {
      
      var avPlayer: AVPlayer
      if let videoPlayer = currentExportPlayer?.avPlayer {
        avPlayer = videoPlayer
      } else {
        avPlayer = localVideoPlayer
      }
      
      // Video is paused. Restart the video
      avPlayer.play()
    }
    
    // Update the app states
    isPaused = false
    pauseButton.isHidden = false
    playButton.isHidden = true
  }
  
  
  private func installUIForVideo() {
    updateAVMute(audioControl: AudioControl.global)
    pauseButton.isHidden = isPaused  // isLikelyToKeepUp can be called when paused, so UI update needs to be correct for that
    playButton.isHidden = !isPaused
    venueButton.isHidden = false
    authorButton.isHidden = false
    displaySwipeStackIfNeeded()
    topStackBackgroundView.isHidden = false
    bottomStackBackgroundView.isHidden = false
    activitySpinner.remove()
  }
  
  
  private func displayMoment(_ moment: FoodieMoment) {
    
    guard let media = moment.media else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Unexpected, moment.media == nil ")
      }
      return
    }
    
    guard let mediaType = media.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Unexpected, mediaObject.mediaType == nil")
      }
      return
    }
    
    // Try to display the media as by type
    if mediaType == .photo {
      guard let imageBuffer = media.imageMemoryBuffer else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { [unowned self] _ in
          CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
          self.popDismiss(animated: true)
        }
        return
      }
      
      // Display the Photo
      photoView.contentMode = .scaleAspectFill
      photoView.image = UIImage(data: imageBuffer)
      view.insertSubview(photoView, belowSubview: jotViewController.view)

      // UI Update - Really should group some of the common UI stuff into some sort of function?
      pauseButton.isHidden = false
      venueButton.isHidden = false
      authorButton.isHidden = false
      displaySwipeStackIfNeeded()
      topStackBackgroundView.isHidden = false
      bottomStackBackgroundView.isHidden = false
      activitySpinner.remove()
      
      // Create timer for advancing to the next media? // TODO: Should not be a fixed time
      photoTimer = Timer.scheduledTimer(withTimeInterval: Constants.MomentsViewingTimeInterval,
                                        repeats: false) { [weak self] timer in
        self?.displayNextMoment()
      }
      
    } else if mediaType == .video {
      
      var avPlayer: AVPlayer
      if let videoPlayer = media.videoExportPlayer?.avPlayer {
        currentExportPlayer = media.videoExportPlayer
        currentExportPlayer!.delegate = self
        avPlayer = videoPlayer
      } else if let localVideoUrl = media.localVideoUrl {
        
        let avUrlAsset = AVURLAsset(url: localVideoUrl)
        let avPlayerItem = AVPlayerItem(asset: avUrlAsset)
        NotificationCenter.default.addObserver(self, selector: #selector(displayNextMoment), name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
        
        localVideoPlayer.replaceCurrentItem(with: avPlayerItem)
        avPlayer = localVideoPlayer
        installUIForVideo()
      } else {
        CCLog.fatal("Video media contains no Export Player nor Local URL")
      }

      avPlayerLayer.player = avPlayer
      view.insertSubview(videoView, belowSubview: jotViewController.view)
      
      avPlayer.seek(to: kCMTimeZero)
      avPlayer.play()

      // No image nor video to work on, Fatal
    } else {
      CCLog.fatal("MediaType neither .photo nor .video")
    }
    
    // See if there are any Markups to Unserialize
    if let markups = moment.markups {
      var jotDictionary = [AnyHashable: Any]()
      var labelDictionary: [NSDictionary]?
      
      for markup in markups {
        
        if !markup.isRetrieved {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("Markup not available even tho Moment \(moment.getUniqueIdentifier()) deemed Loaded")
          }
          return
        }
        
        guard let dataType = markup.dataType else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
            CCLog.assert("Unexpected markup.dataType = nil")
            self.popDismiss(animated: true)
          }
          return
        }
        
        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
            CCLog.assert("markup.dataType did not actually translate into valid type")
            self.popDismiss(animated: true)
          }
          return
        }
        
        switch markupType {
          
        case .jotLabel:
          guard let labelData = markup.data else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
              CCLog.assert("Unexpected markup.data = nil when dataType == .jotLabel")
              self.popDismiss(animated: true)
            }
            return
          }
          
          if labelDictionary == nil {
            labelDictionary = [labelData]
          } else {
            labelDictionary!.append(labelData)
          }
          
        case .jotDrawView:
          guard let drawViewDictionary = markup.data else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
              CCLog.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
              self.popDismiss(animated: true)
            }
            return
          }
          
          jotDictionary[kDrawView] = drawViewDictionary
        }
      }
      
      jotDictionary[kLabels] = labelDictionary
      jotViewController.unserialize(jotDictionary)
    }
  }
  
  
  private func displayMomentIfLoaded(for moment: FoodieMoment) {

    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("viewingStory = nil")
      }
      return
    }
    var shouldRetrieveMoment = false
    
    moment.execute(ifNotReady: {
      CCLog.debug("Moment \(moment.getUniqueIdentifier()) not yet loaded")
      shouldRetrieveMoment = true  // Don't execute the retrieve here. This is actually executed inside of a mutex
      
    }, whenReady: {
      CCLog.debug("Moment \(moment.getUniqueIdentifier()) ready to display")
      DispatchQueue.main.async {
        if let currentMoment = self.currentMoment, currentMoment == moment {
          self.displayMoment(moment)
        }
      }
    })
    
    if shouldRetrieveMoment {
      self.activitySpinner.apply(below: self.tapBackwardGestureRecognizer)
      if draftPreview {
        _ = moment.retrieveRecursive(from: .local, type: .draft, withCompletion: nil)
      } else {
//        let momentOperation = StoryOperation(with: .moment, on: story, for: story.getIndexOf(moment), completion: nil)
//        FoodieFetch.global.queue(momentOperation, at: .high)
      }
    } else {
      CCLog.info("Moment \(moment.getUniqueIdentifier()) displaying")
      self.displayMoment(moment)
    }
  }
  
  
  private func stopAndClear() {
    CCLog.verbose("StoryViewController.stopAndClear()")
    hideAllUI()
    isPaused = false
    
    photoTimer?.invalidate()
    photoTimer = nil
    
    currentExportPlayer?.avPlayer?.pause()
    currentExportPlayer?.delegate = nil
    currentExportPlayer = nil
    
    if let avPlayerItem = localVideoPlayer.currentItem {
      localVideoPlayer.pause()
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
      localVideoPlayer.replaceCurrentItem(with: nil)
    }
    
    // avPlayerLayer.player = nil  // !!! Taking a risk here. So that video transitions will be a touch quicker
    jotViewController.clearAll()
  }
  
  
  private func appearanceForAllUI(alphaValue: CGFloat, animated: Bool) {
    if animated {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
        self.pauseButton.alpha = alphaValue
        self.playButton.alpha = alphaValue
        self.soundOnButton.alpha = alphaValue
        self.soundOffButton.alpha = alphaValue
        self.venueButton.alpha = alphaValue
        self.authorButton.alpha = alphaValue
        self.swipeStack.alpha = alphaValue
        self.topStackBackgroundView.alpha = alphaValue
        self.bottomStackBackgroundView.alpha = alphaValue
      }
    } else {
      pauseButton.alpha = alphaValue
      playButton.alpha = alphaValue
      soundOnButton.alpha = alphaValue
      soundOffButton.alpha = alphaValue
      venueButton.alpha = alphaValue
      authorButton.alpha = alphaValue
      swipeStack.alpha = alphaValue
      topStackBackgroundView.alpha = alphaValue
      bottomStackBackgroundView.alpha = alphaValue
    }
  }
  
  
  private func hideAllUI() {
    pauseButton.isHidden = true
    playButton.isHidden = true
    soundOnButton.isHidden = true
    soundOffButton.isHidden = true
    venueButton.isHidden = true
    authorButton.isHidden = true
    swipeStack.isHidden = true
    topStackBackgroundView.isHidden = true
    bottomStackBackgroundView.isHidden = true
    
  }
  
  
  @objc private func swipeUp(_ sender: UISwipeGestureRecognizer) {
    CCLog.info("User swiped Up")
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.assert("Unexpected, viewingStory = nil")
      }
      return
    }
    
    if let storyLinkString = story.storyURL, let storyLinkUrl = URL(string: URL.addHttpIfNeeded(to: storyLinkString)) {
      pause()
      
      CCLog.info("Opening Safari View for \(storyLinkString)")
      let safariViewController = SFSafariViewController(url: storyLinkUrl)
      safariViewController.delegate = self
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  // Display the next Moment based on what the current Moment is
  @objc private func displayNextMoment() {
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, viewingStory = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, viewingStory.moments = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    guard let moment = currentMoment else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, currentMoment = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    stopAndClear()
    
    // Figure out what is the next moment and display it
    let nextIndex = story.getIndexOf(moment) + 1
    
    if nextIndex == moments.count {
      self.popDismiss(animated: true)
    } else {
      currentMoment = moments[nextIndex]
      self.displayMomentIfLoaded(for: moments[nextIndex])
    }
  }
  
  
  // Display the previous Moment based on what the current Moment is
  private func displayPreviousMoment() {
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, viewingStory = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, viewingStory.moments = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    guard let moment = currentMoment else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, currentMoment = nil")
        self.popDismiss(animated: true)
      }
      return
    }
    
    stopAndClear()
    
    // Figure out what is the previous moment is and display it
    let index = story.getIndexOf(moment)
    
    if index == 0 {
      self.popDismiss(animated: true)
    } else {
      currentMoment = moments[index-1]
      displayMomentIfLoaded(for: moments[index-1])
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if draftPreview {
      view.backgroundColor = .black
    } else {
      view.backgroundColor = .clear
    }
    
    localVideoPlayer.automaticallyWaitsToMinimizeStalling = false
    localVideoPlayer.allowsExternalPlayback = false
    localVideoPlayer.actionAtItemEnd = .none
    
    avPlayerLayer = AVPlayerLayer()
    videoView.layer.addSublayer(avPlayerLayer)
    
    jotViewController.state = JotViewState.disabled
    jotViewController.initialTextInsets = UIEdgeInsetsMake(60, 40, 60, 40)
    jotViewController.fitOriginalFontSizeToViewWidth = true
    addChildViewController(jotViewController)
    
    view.addSubview(jotViewController.view)
    view.insertSubview(jotViewController.view, belowSubview: tapForwardGestureRecognizer)
    jotViewController.didMove(toParentViewController: self)
    
    guard let story = viewingStory else {
      CCLog.fatal("No Story when loading StoryViewController")
    }
    
    if let author = story.author, let username = author.username {
      authorButton.setTitle(username, for: .normal)
    } else {
      CCLog.warning("Cannot get at username from Story \(story.getUniqueIdentifier)")
      authorButton.isHidden = true
    }
    
    if let venue = story.venue, let venueName = venue.name {
      venueButton.setTitle(venueName, for: .normal)
    } else {
      CCLog.info("Cannot get at venue name from Story \(story.getUniqueIdentifier)")
      venueButton.isHidden = true
    }
    
    if let swipeMessage = story.swipeMessage {
      swipeLabel.text = swipeMessage
    } else {
      swipeLabel.isHidden = true
    }
    
    activitySpinner = ActivitySpinner(addTo: view)
    
    swipeUpGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeUp(_:)))
    swipeUpGestureRecognizer.direction = .up
    swipeUpGestureRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(swipeUpGestureRecognizer)
    dragGestureRecognizer?.require(toFail: swipeUpGestureRecognizer)  // This is needed so that the Swipe down to dismiss from OverlayViewController will only have an effect if this is not a Swipe Up to Safari
  }

  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Stop all prefetches but the story being viewed
    guard let story = viewingStory else {
      CCLog.fatal("Entered StoryVC with viewingStory = nil")
    }
    FoodieFetch.global.cancelAllButOne(story)
    
    isAppearanceLayout = true
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      
      // Setup Background Gradient Views
      let backgroundBlackAlpha = UIColor.black.withAlphaComponent(Constants.BackgroundGradientBlackAlpha)
      let topGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 0.0),
                                         endingAt: CGPoint(x: 0.5, y: 1.0),
                                         with: [backgroundBlackAlpha, .clear])
      topGradientNode.isOpaque = false
      topGradientNode.frame = topStackBackgroundView.bounds
      topStackBackgroundView.addSubnode(topGradientNode)
      
      let bottomGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                            endingAt: CGPoint(x: 0.5, y: 0.0),
                                            with: [backgroundBlackAlpha, .clear])
      bottomGradientNode.isOpaque = false
      bottomGradientNode.frame = bottomStackBackgroundView.bounds
      bottomStackBackgroundView.addSubnode(bottomGradientNode)
    }
    
    if isAppearanceLayout {
      isAppearanceLayout = false
      
      avPlayerLayer.frame = videoView.bounds
      jotViewController.view.frame = videoView.frame
      jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                               andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)
      jotViewController.view.layoutIfNeeded()
      
      guard let story = viewingStory else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
          CCLog.assert("Unexpected viewingStory = nil")
          self.popDismiss(animated: true)
        }
        return
      }
      
      guard let moments = story.moments, !moments.isEmpty else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
          CCLog.assert("Unexpected viewingStory.moments = nil or empty")
          self.popDismiss(animated: true)
        }
        return
      }
      
      // If a moment was already in play, just display that again. Otherwise try to display the first moment
      if currentMoment == nil {
        currentMoment = moments[0]
        hideAllUI()
        displayMomentIfLoaded(for: currentMoment!)
        
      } else {
        CCLog.debug("Calling play()")
        play()
      }
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    muteObserver = AudioControl.observeMuteState(withBlock: updateAVMute)
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
     pause()
    
    // Cancel All potential Prefetch associated with the Story before disappearing
    if let story = viewingStory {
      FoodieFetch.global.cancel(for: story)
    } else {
      CCLog.assert("Expected a viewingStory even tho dismissing")
    }
    
    // Need to Invalidate and nil in-order to break retain cycle
    muteObserver?.invalidate()
    muteObserver = nil
  }
  
  
  override func topViewWillEnterForeground() {
    super.topViewWillEnterForeground()
    
    guard let media = currentMoment?.media else { return }
    
    if media.mediaType == .video {
      if let exportPlayer = currentExportPlayer {
        exportPlayer.avPlayer?.play()
      } else {
        localVideoPlayer.play()
      }
    }
  }
  
  
  deinit {
    CCLog.debug("Deinit")
    stopAndClear()
  }
  
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
}



// MARK: - Safari View Controller Did Finish Delegate Conformance
extension StoryViewController: SFSafariViewControllerDelegate {
  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    CCLog.debug("Calling play()")
    play()
  }
}



// MARK: - AVPlayAndExportDelegate Conformance
extension StoryViewController: AVPlayAndExportDelegate {
 
  func avExportPlayer(isLikelyToKeepUp avExportPlayer: AVExportPlayer) {
    installUIForVideo()
  }
  
  func avExportPlayer(isWaitingForData avExportPlayer: AVExportPlayer) {
    hideAllUI()
    activitySpinner.apply(below: tapBackwardGestureRecognizer)
  }
  
  func avExportPlayer(completedPlaying avExportPlayer: AVExportPlayer) {
    displayNextMoment()
  }
}
