//
//  ProfileViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ProfileViewController: OverlayViewController {
  
  // MARK: - Constants
  
  struct Constants {
    static let PercentageOfStoryVisibleToStartPrefetch: CGFloat = 0.9
  }
  
  
  
  // MARK: - Private Instance Variables
  
  private var feedCollectionNodeController: FeedCollectionNodeController?
  private var activitySpinner: ActivitySpinner!
  private var isInitialLayout = true
  
  
  
  // MARK: - Public Instance Variable
  
  var user: FoodieUser?
  var query: FoodieQuery?
  var stories = [FoodieStory]() {
    didSet {
      feedCollectionNodeController?.resetCollectionNode(with: stories)
    }
  }
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var feedContainerView: UIView!
  @IBOutlet weak var mapExposedView: UIView!
  @IBOutlet weak var profileUIView: UIView!
  @IBOutlet weak var avatarView: UIView!
  @IBOutlet weak var followButton: UIButton!
  @IBOutlet weak var settingsButton: UIButton!
  @IBOutlet weak var shareButton: UIButton!
  @IBOutlet weak var filterButton: UIButton!
  @IBOutlet weak var fullnameLabel: UILabel!
  @IBOutlet weak var usernameLabel: UILabel!
  @IBOutlet weak var websiteLabel: UILabel!
  @IBOutlet weak var bioLabel: UILabel!
  
  
  
  // MARK: - IBAction
  
  @IBAction func settingsAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of SettingsViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
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
      self.stories = stories
    }
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    guard let user = user, user.isRegistered else {
      AlertDialog.present(from: self, title: "Profile Error", message: "The specified user profile belongs to an unregistered user") { _ in
        CCLog.assert("Entered Profile View but no valid registered user specified")
        self.popDismiss(animated: true)
      }
      return
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
//    followButton.isHidden = true
//    shareButton.isHidden = true
//    filterButton.isHidden = true
  }
  
  
  override func viewDidLayoutSubviews() {
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
    }
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
    
//    if let storyIndex = feedCollectionNodeController.highlightedStoryIndex {
//      for annotation in mapNavController.mapView.annotations {
//        if let storyAnnotation = annotation as? StoryMapAnnotation, storyAnnotation.story === storyArray[storyIndex] {
//          mapNavController.selectInExposedRect(annotation: storyAnnotation)
//        }
//      }
//    }
    
    // Do Prefetching
    let storiesIndexes = feedCollectionNodeController.getStoryIndexesVisible(forOver: Constants.PercentageOfStoryVisibleToStartPrefetch)
    let storiesShouldPrefetch = storiesIndexes.map { stories[$0] }
    FoodieFetch.global.cancelAllBut(storiesShouldPrefetch)
  }
}
