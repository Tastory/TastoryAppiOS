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
    static let PercentageOfStoryVisibleToStartPrefetch: CGFloat = 0.5
  }
  
  
  // MARK: - Private Instance Variables
  private var feedCollectionNodeController: FeedCollectionNodeController?
  fileprivate var activitySpinner: ActivitySpinner!
  
  // MARK: - Public Instance Variable
  var user: FoodieUser?
  var query: FoodieQuery?
  var stories = [FoodieStory]() {
    didSet {
      feedCollectionNodeController?.resetCollectionNode(with: stories)
    }
  }
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var navBar: UINavigationBar!
  @IBOutlet weak var feedContainerView: UIView!
  
  
  // MARK: - IBAction
  @IBAction func backAction(_ sender: UIBarButtonItem) {
    popDismiss(animated: true)
  }
  
  
  @IBAction func settingsAction(_ sender: UIBarButtonItem) {
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

    navBar.delegate = self

    guard let user = user, user.isRegistered else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Entered Profile View but no valid registered user specified")
        self.popDismiss(animated: true)
      }
      return
    }

    // Change the Title to the Username
    //    if let username = user.username {
    //      navBar.topItem?.title = username
    //    } else {
    navBar.topItem?.title = "Your Stories"
    //    }

    // Query everything by this user
    query = FoodieQuery()
    query!.addAuthorsFilter(users: [user])

    query!.setSkip(to: 0)
    query!.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)
    _ = query!.addArrangement(type: .creationTime, direction: .descending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determins feed order

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
      
    let nodeController = FeedCollectionNodeController(with: .mosaic, offsetBy: navBar.frame.height, allowLayoutChange: false, adjustScrollViewInset: true)
    nodeController.storyArray = stories
    nodeController.enableEdit = true
    addChildViewController(nodeController)
    feedContainerView.addSubview(nodeController.view)
    nodeController.view.frame = feedContainerView.bounds
    nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    nodeController.didMove(toParentViewController: self)
    nodeController.delegate = self
    feedCollectionNodeController = nodeController
    

    activitySpinner.apply()
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
}

extension ProfileViewController: UINavigationBarDelegate {
  func position(for bar: UIBarPositioning) -> UIBarPosition {
    return UIBarPosition.topAttached
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
