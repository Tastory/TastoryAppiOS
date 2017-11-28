//
//  ProfileViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit
import SafariServices

class ProfileViewController: OverlayViewController {
  
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
  private var avatarImageNode: ASNetworkImageNode?
  private var activitySpinner: ActivitySpinner!
  private var isInitialLayout = true
  private var isAppearanceLayout = true
  
  
  
  // MARK: - Public Instance Variable
  
  var user: FoodieUser?
  var query: FoodieQuery?
  var stories = [FoodieStory]() {
    didSet {
      feedCollectionNodeController?.resetCollectionNode(with: stories)
      feedCollectionNodeController?.scrollTo(storyIndex: 0)
    }
  }
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var feedContainerView: UIView!
  @IBOutlet weak var topGradientBackground: UIView!
  @IBOutlet weak var mapExposedView: UIView!
  @IBOutlet weak var profileUIView: UIView!
  @IBOutlet weak var avatarFrameView: UIImageView!
  @IBOutlet weak var addPhotoButton: UIButton!
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
  
  
  
  // MARK: - IBAction
  
  @IBAction func settingsAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsNavViewController") as? SettingsNavViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of SettingsNavViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func websiteTapAction(_ sender: UITapGestureRecognizer) {
    if let websiteString = websiteLabel.text, let websiteUrl = URL(string: URL.addHttpIfNeeded(to: websiteString)) {
      CCLog.info("Opening Safari View for \(websiteUrl)")
      let safariViewController = SFSafariViewController(url: websiteUrl)
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  
  @IBAction func addPhotoAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsNavViewController") as? SettingsNavViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of SettingsNavViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func backAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }
  
  
  
  // MARK: - Private Instance Functions
  
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
  
  
  private func retrieveStoryDigests(_ stories: [FoodieStory]) {
    for story in stories {
      _ = story.retrieveDigest(from: .both, type: .cache) { error in
        if let error = error {
          AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story Digest - \(error.localizedDescription)") { action in
            CCLog.warning("Failed to retrieve Story Digest via story.retrieveDigest. Error - \(error.localizedDescription)")
          }
          return
        }
        guard let venue = story.venue, venue.location != nil, venue.isDataAvailable else {
          CCLog.assert("No Title, Venue or Location to Story. Skipping Story")
          return
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

    guard let user = user, user.isRegistered else {
      AlertDialog.present(from: self, title: "Profile Error", message: "The specified user profile belongs to an unregistered user") { _ in
        CCLog.assert("Entered Profile View but no valid registered user specified")
        self.popDismiss(animated: true)
      }
      return
    }
    
    settingsButton.imageView?.contentMode = .scaleAspectFit
    followButton.imageView?.contentMode = .scaleAspectFit
    shareButton.imageView?.contentMode = .scaleAspectFit
    filterButton.imageView?.contentMode = .scaleAspectFit
    
    // Drop Shadow at the back of the UI View
    profileUIView.layer.masksToBounds = false
    profileUIView.layer.shadowColor = UIColor.black.cgColor
    profileUIView.layer.shadowOffset = Constants.StackShadowOffset
    profileUIView.layer.shadowRadius = Constants.StackShadowRadius
    profileUIView.layer.shadowOpacity = Constants.StackShadowOpacity
    
    // Query everything by this user
    query = FoodieQuery()
    query!.addAuthorsFilter(users: [user])

    query!.setSkip(to: 0)
    query!.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)
    _ = query!.addArrangement(type: .creationTime, direction: .descending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determines feed order

    activitySpinner = ActivitySpinner(addTo: view)
    activitySpinner.apply()

    // Actually do the Query
    query!.initStoryQueryAndSearch { (stories, error) in
      self.activitySpinner.remove()

      if let err = error {
        AlertDialog.present(from: self, title: "Query Failed", message: "Please check your network connection and try again") { action in
          CCLog.assert("Create Story Query & Search failed with error: \(err.localizedDescription)")
        }
        return
      }

      guard let stories = stories else {
        AlertDialog.present(from: self, title: "Query Failed", message: "Please check your network connection and try again") { action in
          CCLog.assert("Create Story Query & Search returned with nil Story Array")
        }
        return
      }
      
      // Show empty message if applicable
      if stories.count <= 0 {
        if user === FoodieUser.current {
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
        
        self.retrieveStoryDigests(stories)
        self.stories = stories
      }
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: false)
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    guard let user = user, user.isRegistered else {
      AlertDialog.present(from: self, title: "Profile Error", message: "The specified user profile belongs to an unregistered user") { _ in
        CCLog.assert("Entered Profile View but no valid registered user specified")
        self.popDismiss(animated: true)
      }
      return
    }
    
    if let avatarFileName = user.profileMediaFileName {
      if let mediaTypeString = user.profileMediaType, let mediaType = FoodieMediaType(rawValue: mediaTypeString), mediaType == .photo {
        // Only Photo Avatars are supported at the moment
        avatarImageNode = ASNetworkImageNode()
        avatarImageNode!.url = FoodieFileObject.getS3URL(for: avatarFileName)
        avatarImageNode!.contentMode = .scaleAspectFill
        avatarImageNode!.placeholderColor = UIColor.white
        avatarImageNode!.placeholderEnabled = true
        //avatarImageNode!.isLayerBacked = true
        
        addPhotoButton.isHidden = true
      } else {
        CCLog.warning("Unsupported Avatar Media Type - \(user.profileMediaType ?? "Media Type == nil")")
        addPhotoButton.isHidden = false
      }
    } else {
      addPhotoButton.isHidden = false
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
    
    // Hide all the other buttons for now
    followButton.isHidden = true
    shareButton.isHidden = true
    filterButton.isHidden = true
    
    isAppearanceLayout = true
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      let nodeController = FeedCollectionNodeController(with: .mosaic,
                                                        offsetBy: profileUIView.bounds.height,
                                                        allowLayoutChange: false,
                                                        adjustScrollViewInset: true)
      nodeController.storyArray = stories
      nodeController.enableEdit = true
      addChildViewController(nodeController)
      feedContainerView.addSubnode(nodeController.node)
      nodeController.node.frame = feedContainerView.bounds
      nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      nodeController.didMove(toParentViewController: self)
      nodeController.delegate = self
      feedCollectionNodeController = nodeController
      
      if let avatarImageNode = avatarImageNode {
        avatarImageNode.frame = avatarFrameView.frame.insetBy(dx: 2.0, dy: 2.0)
        view.addSubnode(avatarImageNode)
        view.insertSubview(avatarImageNode.view, belowSubview: avatarFrameView)
        
        // Mask the avatar
        guard let maskImage = UIImage(named: "Profile-BloatedSquareMask") else {
          CCLog.fatal("Cannot get at Profile-BloatedSquareMask in Resource Bundle")
        }
        
        let maskLayer = CALayer()
        maskLayer.contents = maskImage.cgImage
        maskLayer.frame = avatarImageNode.bounds
        avatarImageNode.layer.mask = maskLayer
      }
    }
    
    if isAppearanceLayout {
      isAppearanceLayout = false
      
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Map Navigation Controller. Cannot Proceed")
      }
      return
    }
    
    mapNavController = mapController
    //mapController.mapDelegate = self
    mapController.setExposedRect(with: mapExposedView)
    
    appearanceForAllUI(alphaValue: 1.0, animated: true)
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
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
