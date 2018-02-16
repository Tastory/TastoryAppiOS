//
//  ProfileViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AsyncDisplayKit
import SafariServices

class ProfileViewController: OverlayViewController {

  // MARK: - Types and Enumeration

  enum LayoutType: Int {
    case user
    case venue
  }

  // MARK: - Constants
  
  struct Constants {
    static let PercentageOfStoryVisibleToStartPrefetch: CGFloat = 0.9
    static let StackShadowOffset = FoodieGlobal.Constants.DefaultUIShadowOffset
    static let StackShadowRadius = FoodieGlobal.Constants.DefaultUIShadowRadius
    static let StackShadowOpacity = FoodieGlobal.Constants.DefaultUIShadowOpacity
    
    static let TopGradientBlackAlpha: CGFloat = 0.3
    static let BottomGradientBlackAlpha: CGFloat = 0.7
    static let UIDisappearanceDuration = FoodieGlobal.Constants.DefaultUIDisappearanceDuration
  }
  
  
  
  // MARK: - Private Instance Variables
  
  private var feedCollectionNodeController: FeedCollectionNodeController?
  private var mapNavController: MapNavController?
  private var avatarImageNode: ASNetworkImageNode!
  private var activitySpinner: ActivitySpinner!
  private var isInitialLayout = true

  private var removeStoryList: [FoodieStory] = []
  private var updateStoryList: [FoodieStory] = []
  


  // MARK: - Public Instance Variable
  var user: FoodieUser? {
    didSet {
      layout = .user
    }
  }

  var venue: FoodieVenue? {
    didSet {
      layout = .venue
    }
  }

  var query: FoodieQuery?
  var stories = [FoodieStory]() {
    didSet {
      feedCollectionNodeController?.resetCollectionNode(with: stories)
      feedCollectionNodeController?.scrollTo(storyIndex: 0)
    }
  }
  private var layout: LayoutType = .user

  
  // MARK: - IBOutlet
  
  @IBOutlet weak var feedContainerView: UIView!
  @IBOutlet weak var mapExposedView: UIView!
  @IBOutlet weak var topGradientBackground: UIView!
  @IBOutlet weak var touchForwardingView: TouchForwardingView? {
    didSet {
      if let touchForwardingView = touchForwardingView,
        let mapNavController = navigationController as? MapNavController {
        touchForwardingView.passthroughViews = [mapNavController.mapView]
      }
    }
  }
  
  @IBOutlet weak var profileUIView: UIView!
  @IBOutlet weak var emptyAvatarImageView: UIImageView!
  @IBOutlet weak var avatarFrameView: UIImageView!
  @IBOutlet weak var followButton: UIButton!
  @IBOutlet weak var settingsButton: UIButton!
  @IBOutlet weak var shareButton: UIButton!
  @IBOutlet weak var filterButton: UIButton!
  @IBOutlet weak var fullnameLabel: UILabel!
  @IBOutlet weak var usernameLabel: UILabel!
  @IBOutlet weak var websiteLabel: UILabel!
  @IBOutlet weak var bioLabel: UILabel!
  @IBOutlet weak var noStoriesSelfImageView: UIImageView!
  @IBOutlet weak var noStoriesOthersImageView: UIImageView!
  @IBOutlet weak var moreButton: UIButton!

  
  
  // MARK: - IBAction
  @IBAction func moreAction(_ sender: UIButton) {

    guard let venue = venue else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Venue is nil")
      }
      return
    }

    guard let location = venue.location else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Location is missing from venue")
      }
      return
    }

    guard let venueName = venue.name else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("The venue name is missing")
      }
      return
    }

    let fourSquareButton =
      UIAlertAction(title: "Foursquare", comment: "Button for viewing info at foursquare", style: .default) { (UIAlertAction) -> Void in
        guard let urlStr = venue.foursquareURL else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("foursquare url is nil")
          }
          return
        }

        guard let fourSquareURL = URL(string: urlStr) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occurred when generating the foursquare url")
          }
          return
        }
        UIApplication.shared.open(fourSquareURL)
    }

    let googleButton =
      UIAlertAction(title: "Google Maps", comment: "Button for viewing info at google", style: .default) { (UIAlertAction) -> Void in
        guard let escapedVenueName:String = venueName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occurred when generating the google url")
          }
          return
        }
        let url =  "https://www.google.ca/maps/search/\(escapedVenueName)/@\(location.latitude),\(location.longitude),15z"

        guard let googleURL = URL(string: url) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occurred when generating the google map url")
          }
          return
        }
        UIApplication.shared.open(googleURL)
    }

    let yelpButton =
      UIAlertAction(title: "Yelp", comment: "Button for viewing info at yelp", style: .default) { (UIAlertAction) -> Void in
        var components = URLComponents(string: "https://www.yelp.ca/search")!
        components.queryItems = [
          URLQueryItem(name: "find_desc",       value: venueName),
          URLQueryItem(name: "l", value: "a:\(location.latitude),\(location.longitude)0000001,55")
        ]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let yelpURL = components.url else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occurred when generating the yelp url")
          }
          return
        }
        UIApplication.shared.open(yelpURL)
    }

    let actionSheet = UIAlertController(title: "More information at",
                                        titleComment: "Title for more information dialog",
                                        message: nil, messageComment: nil,
                                        preferredStyle: .actionSheet)

    actionSheet.addAction(fourSquareButton)
    actionSheet.addAction(googleButton)
    actionSheet.addAction(yelpButton)
    actionSheet.addAlertAction(title: "Cancel",
                               comment: "Action Sheet button for Cancelling more information action",
                               style: .cancel)
    self.present(actionSheet, animated: true, completion: nil)
  }

  @IBAction func settingsAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsNavViewController") as? SettingsNavViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of SettingsNavViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }

  @IBAction func shareAction(_ sender: Any) {

    guard let deepLink = DeepLink.global else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Cannot get deeplink from AppDelegate")
      }
      return
    }

    if let user = user {
      deepLink.createProfileDeepLink(user: user) { (url, error) in
        if error != nil {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occured when generating link \(error!.localizedDescription))")
          }
          return
        }

        guard let url = url else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("No link generated")
          }
          return
        }

        // button reference for ipad pop up controller anchoring
        guard let button = sender as? UIButton else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("No link generated")
          }
          return
        }

        SharedDialog.showPopUp(url: url, fromVC: self, sender: button)
      }
    } else if let venue = venue {
      deepLink.createVenueDeepLink(venue: venue) { (url, error) in
        if error != nil {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occured when generating link \(error!.localizedDescription))")
          }
          return
        }

        guard let url = url else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("No link generated")
          }
          return
        }

        // button reference for ipad pop up controller anchoring
        guard let button = sender as? UIButton else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("No link generated")
          }
          return
        }

        SharedDialog.showPopUp(url: url, fromVC: self, sender: button)
      }
    } else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Nothing was shared .....")
      }
    }





  }
  
  
  @IBAction func websiteTapAction(_ sender: UITapGestureRecognizer) {
    if let websiteString = websiteLabel.text, let websiteUrl = URL(string: URL.addHttpIfNeeded(to: websiteString)) {
      CCLog.info("Opening Safari View for \(websiteUrl)")
      let safariViewController = SFSafariViewController(url: websiteUrl)
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  @IBAction func backAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }
  
  
  
  // MARK: - Private Instance Functions

  @objc func updateFeed(_ notification: NSNotification) {

    guard let userInfo = notification.userInfo else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("userInfo is missing from notification")
      }
      return
    }

    guard let action = userInfo[FoodieGlobal.RefreshFeedNotification.ActionKey] else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("action is not in userInfo")
      }
      return
    }

    guard let story = userInfo[FoodieGlobal.RefreshFeedNotification.WorkingStoryKey] else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("workingStory is not in userInfo")
      }
      return
    }

    let actionStr = action as! String
    let workingStory = story as! FoodieStory

    if(actionStr == FoodieGlobal.RefreshFeedNotification.UpdateAction) {
       updateStoryList.append(workingStory)
    }

    if(actionStr == FoodieGlobal.RefreshFeedNotification.DeleteAction) {

      // remove from update list if a story is marked for update and delete at the same time
      if(updateStoryList.contains(workingStory)) {
        updateStoryList.remove(at: updateStoryList.index(of: workingStory)!)
      }
      removeStoryList.append(workingStory)
    }
  }

  private func updateProfileMap(with story: FoodieStory) {
    let minMapWidth = mapNavController?.minMapWidth ?? MapNavController.Constants.DefaultMinMapWidth
    
    if let venue = story.venue, venue.isDataAvailable {
      guard let location = venue.location else {
        CCLog.warning("Venue with no Location")
        return
      }
      
      DispatchQueue.main.async {
        let coordinate = CLLocationCoordinate2DMake(location.latitude, location.longitude)
        let region = MKCoordinateRegionMakeWithDistance(coordinate, minMapWidth, minMapWidth)
        
        self.mapNavController?.removeAllAnnotations()
        self.mapNavController?.showRegionExposed(region, animated: true)
        
        // Add back if an annotation is requested
        if let name = venue.name {
          let annotation = StoryMapAnnotation(title: name, story: story, coordinate: region.center)
          self.mapNavController?.add(annotation: annotation)
          self.mapNavController?.select(annotation: annotation, animated: true)
        }
      }
    }
  }
  
  
  private func appearanceForAllUI(alphaValue: CGFloat, animated: Bool,
                                  duration: TimeInterval = FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
    if animated {
      UIView.animate(withDuration: duration) {
        self.topGradientBackground.alpha = alphaValue
        self.feedContainerView.alpha = alphaValue
        self.noStoriesSelfImageView.alpha = alphaValue
        self.noStoriesOthersImageView.alpha = alphaValue
      }
    } else {
      topGradientBackground.alpha = alphaValue
      feedContainerView.alpha = alphaValue
      noStoriesSelfImageView.alpha = alphaValue
      noStoriesOthersImageView.alpha = alphaValue
    }
  }

  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()

    NotificationCenter.default.addObserver(self, selector: #selector(self.updateFeed(_:)), name: NSNotification.Name(rawValue: FoodieGlobal.RefreshFeedNotification.NotificationId), object: nil)

    settingsButton.imageView?.contentMode = .scaleAspectFit
    followButton.imageView?.contentMode = .scaleAspectFit
    shareButton.imageView?.contentMode = .scaleAspectFit
    filterButton.imageView?.contentMode = .scaleAspectFit
    moreButton.imageView?.contentMode = .scaleAspectFit

    // Add the Avatar Image Node first
    avatarImageNode = ASNetworkImageNode()
    avatarImageNode.contentMode = .scaleAspectFill
    avatarImageNode.placeholderColor = UIColor.white
    avatarImageNode.placeholderEnabled = true
    view.addSubnode(avatarImageNode)
    view.insertSubview(avatarImageNode.view, belowSubview: emptyAvatarImageView)

    // Drop Shadow at the back of the UI View
    profileUIView.layer.masksToBounds = false
    profileUIView.layer.shadowColor = UIColor.black.cgColor
    profileUIView.layer.shadowOffset = Constants.StackShadowOffset
    profileUIView.layer.shadowRadius = Constants.StackShadowRadius
    profileUIView.layer.shadowOpacity = Constants.StackShadowOpacity


    query = FoodieQuery()

    if layout == .venue {
      guard let venue = venue else {
        AlertDialog.present(from: self, title: "Profile Error", message: "The specified restaurant page doesn't exist") { [unowned self] _ in
          CCLog.assert("Entered Profile View but no valid venue found")
          self.popDismiss(animated: true)
        }
        return
      }

      guard let venueObjId = venue.objectId else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)  { [unowned self] _ in
          CCLog.assert("FoodieVenue is missing object id")
          self.popDismiss(animated: true)
        }
        return
      }

      query!.addVenueFilter(venueId: venueObjId)
    } else {
      guard let user = user, user.isRegistered else {
        AlertDialog.present(from: self, title: "Profile Error", message: "The specified user profile belongs to an unregistered user") { [unowned self] _ in
          CCLog.assert("Entered Profile View but no valid registered user specified")
          self.popDismiss(animated: true)
        }
        return
      }

      // Query everything by this user
      query!.addAuthorsFilter(users: [user])
    }

    query!.setSkip(to: 0)
    query!.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)

    _ = query!.addArrangement(type: .creationTime, direction: .descending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determines feed order

    activitySpinner = ActivitySpinner(addTo: view)
    activitySpinner.apply()

    // Actually do the Query
    query!.initStoryQueryAndSearch { (stories, error) in
      self.activitySpinner.remove()

      if let err = error {
        AlertDialog.present(from: self, title: "Query Failed", message: "Please check your network connection and try again") { _ in
          CCLog.assert("Create Story Query & Search failed with error: \(err.localizedDescription)")
        }
        return
      }

      guard let stories = stories else {
        AlertDialog.present(from: self, title: "Query Failed", message: "Please check your network connection and try again") { _ in
          CCLog.assert("Create Story Query & Search returned with nil Story Array")
        }
        return
      }

      // Show empty message if applicable
      if stories.count <= 0 {
        if self.layout == .user , self.user === FoodieUser.current {
          self.noStoriesSelfImageView.isHidden = false
          self.noStoriesOthersImageView.isHidden = true
          self.feedContainerView.isHidden = true
        } else {
          self.noStoriesSelfImageView.isHidden = true
          self.noStoriesOthersImageView.isHidden = false
          self.feedContainerView.isHidden = true
        }
      } else {
        self.noStoriesSelfImageView.isHidden = true
        self.noStoriesOthersImageView.isHidden = true
        self.feedContainerView.isHidden = false
        self.stories = stories

        DispatchQueue.main.async {
          self.feedCollectionNodeController?.scrollTo(storyIndex: 0)
          self.updateProfileMap(with: stories[0])
          self.feedCollectionNodeController?.processDeepLinkStoryIfAvail()
        }
      }
    }
    appearanceForAllUI(alphaValue: 0.0, animated: false)
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if(layout == .venue) {
      guard let venue = venue else {
        AlertDialog.present(from: self, title: "Profile Error", message: "The specified restaurant page doesn't exist") { [unowned self] _ in
          CCLog.assert("Entered Profile View but no valid venue found")
          self.popDismiss(animated: true)
        }
        return
      }

      emptyAvatarImageView.isHidden = false
      usernameLabel.isHidden = true

      if let fullname = venue.name?.trimmingCharacters(in: .whitespacesAndNewlines), fullname != "" {
        fullnameLabel.text = fullname
      } else {
        fullnameLabel.isHidden = true
      }

      if let websiteUrl = venue.venueURL?.trimmingCharacters(in: .whitespacesAndNewlines), websiteUrl != "" {
        websiteLabel.text = websiteUrl
      } else {
        websiteLabel.isHidden = true
      }

      shareButton.isHidden = false
      moreButton.isHidden = (layout == .user)

      // Hide all the other buttons for now
      settingsButton.isHidden = true
      followButton.isHidden = true
      filterButton.isHidden = true
      bioLabel.isHidden = true

    } else {
      guard let user = user, user.isRegistered else {
        AlertDialog.present(from: self, title: "Profile Error", message: "The specified user profile belongs to an unregistered user") { [unowned self] _ in
          CCLog.assert("Entered Profile View but no valid registered user specified")
          self.popDismiss(animated: true)
        }
        return
      }

      if let avatarFileName = user.profileMediaFileName {
        if let mediaTypeString = user.profileMediaType, let mediaType = FoodieMediaType(rawValue: mediaTypeString), mediaType == .photo {
          // Only Photo Avatars are supported at the moment
          avatarImageNode!.url = FoodieFileObject.getS3URL(for: avatarFileName)
          emptyAvatarImageView.isHidden = true
        } else {
          CCLog.warning("Unsupported Avatar Media Type - \(user.profileMediaType ?? "Media Type == nil")")
          emptyAvatarImageView.isHidden = false
        }
      } else {
        emptyAvatarImageView.isHidden = false
      }

      guard let username = user.username else {
        AlertDialog.present(from: self, title: "User Error", message: "User has no username. Please try another user") { _ in
          CCLog.assert("A user does not have a username")
        }
        return
      }

      if let fullname = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), fullname != "" {
        fullnameLabel.text = fullname
        usernameLabel.text = "@ \(username)"
      } else {
        fullnameLabel.text = "@ \(username)"
        usernameLabel.isHidden = true
      }

      if let websiteUrl = user.url?.trimmingCharacters(in: .whitespacesAndNewlines), websiteUrl != "" {
        websiteLabel.text = websiteUrl
      } else {
        websiteLabel.isHidden = true
      }

      if let biography = user.biography?.trimmingCharacters(in: .whitespacesAndNewlines), biography != "" {
        bioLabel.text = biography
      } else {
        bioLabel.isHidden = true
      }

      if user === FoodieUser.current {
        settingsButton.isHidden = false
      } else {
        settingsButton.isHidden = true
      }

      shareButton.isHidden = false
      moreButton.isHidden = (layout == .user)

      // Hide all the other buttons for now
      followButton.isHidden = true
      filterButton.isHidden = true
    }
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      let nodeController = FeedCollectionNodeController(with: .mosaic,
                                                        offsetBy: MosaicCollectionViewLayout.Constants.DefaultFeedNodeMargin, //profileUIView.bounds.height,
                                                        allowLayoutChange: false,
                                                        adjustScrollViewInset: true)
      nodeController.storyArray = stories
      nodeController.delegate = self
      nodeController.deepLinkStoryId = DeepLink.global.deepLinkStoryId

      if user === FoodieUser.current {
        nodeController.enableEdit = true
      } else {
        nodeController.enableEdit = false
      }
      addChildViewController(nodeController)
      feedContainerView.addSubnode(nodeController.node)
      nodeController.node.frame = feedContainerView.bounds
      nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      nodeController.didMove(toParentViewController: self)
      feedCollectionNodeController = nodeController
      
      
      // Layout the Avatar Image Node
      avatarImageNode.frame = avatarFrameView.frame.insetBy(dx: 2.0, dy: 2.0)
      
      // Mask the avatar
      guard let maskImage = UIImage(named: "Profile-BloatedSquareMask") else {
        CCLog.fatal("Cannot get at Profile-BloatedSquareMask in Resource Bundle")
      }
      
      let maskLayer = CALayer()
      maskLayer.contents = maskImage.cgImage
      maskLayer.frame = avatarImageNode.bounds
      avatarImageNode.layer.mask = maskLayer
      
      
      // Setup Background Gradient Views
      let topBackgroundBlackAlpha = UIColor.black.withAlphaComponent(Constants.TopGradientBlackAlpha)
      let topGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 0.0),
                                         endingAt: CGPoint(x: 0.5, y: 1.0),
                                         with: [topBackgroundBlackAlpha, .clear])
      topGradientNode.isOpaque = false
      topGradientNode.frame = topGradientBackground.bounds
      topGradientBackground.addSubnode(topGradientNode)
      topGradientBackground.sendSubview(toBack: topGradientNode.view)
      
      let bottomBackgroundBlackAlpha = UIColor.black.withAlphaComponent(Constants.BottomGradientBlackAlpha)
      let bottomGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                            endingAt: CGPoint(x: 0.5, y: 0.0),
                                            with: [bottomBackgroundBlackAlpha, .clear])
      bottomGradientNode.isOpaque = false
      bottomGradientNode.frame = feedContainerView.bounds
      feedContainerView.addSubnode(bottomGradientNode)
      feedContainerView.sendSubview(toBack: bottomGradientNode.view)
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    guard let mapController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Map Navigation Controller. Cannot Proceed")
      }
      return
    }
    
    mapNavController = mapController
    //mapController.mapDelegate = self

    if let mapExposedView = mapExposedView {
      mapController.setExposedRect(with: mapExposedView)
    }
    
    if let touchForwardingView = touchForwardingView {
      touchForwardingView.passthroughViews = [mapController.mapView]
    }
    
    guard let feedCollectionNodeController = feedCollectionNodeController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Expected FeedCollectionNodeController")
      }
      return
    }
    
    if let storyIndex = feedCollectionNodeController.highlightedStoryIndex, storyIndex < stories.count {
      updateProfileMap(with: stories[storyIndex])
    }

    if(stories.count == 0) {
      mapController.removeAllAnnotations()
    }
    
    appearanceForAllUI(alphaValue: 1.0, animated: true)

    if(removeStoryList.count > 0) {

      for delStory in removeStoryList {

        let storyIdx = stories.index(of: delStory)

        guard let storyIndex = storyIdx else {
          CCLog.warning("Story not found in the storyArray. Nothing to delete")
          return
        }

        stories.remove(at: storyIndex)
      }

      for updateStory in updateStoryList {
        let storyIdx = stories.index(of: updateStory)

        guard let storyIndex = storyIdx else {
          CCLog.warning("Story not found in the storyArray. Nothing to update")
          return
        }

        stories[storyIndex] = updateStory
      }

      feedCollectionNodeController.resetCollectionNode(with: stories)
      feedCollectionNodeController.scrollTo(storyIndex: 0)
      removeStoryList.removeAll()
      updateStoryList.removeAll()
    } else {
      if(updateStoryList.count > 0) {
        for story in updateStoryList {
          feedCollectionNodeController.updateStory(story)
        }
        updateStoryList.removeAll()
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    mapNavController = nil
  }
  
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  
  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    return .fade
  }
  
}


extension ProfileViewController: FeedCollectionNodeDelegate {
  
  func collectionNodeDidStopScrolling() {

    guard let feedCollectionNodeController = feedCollectionNodeController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Expected FeedCollectionNodeController")
      }
      return
    }

    if let storyIndex = feedCollectionNodeController.highlightedStoryIndex, storyIndex < stories.count {
      updateProfileMap(with: stories[storyIndex])
    }
    
    // Do Prefetching
    let storiesIndexes = feedCollectionNodeController.getStoryIndexesVisible(forOver: Constants.PercentageOfStoryVisibleToStartPrefetch)
    let storiesShouldPrefetch = storiesIndexes.map { stories[$0] }
    FoodieFetch.global.cancelAllBut(storiesShouldPrefetch)
  }
}
