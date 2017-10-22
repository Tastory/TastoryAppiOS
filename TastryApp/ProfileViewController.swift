//
//  ProfileViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ProfileViewController: TransitableViewController {
  
  // MARK: - Private Instance Variables
  private var feedCollectionViewController: FeedCollectionViewController?
  
  
  // MARK: - Public Instance Variable
  var user: FoodieUser?
  var query: FoodieQuery? {
    didSet {
      feedCollectionViewController?.storyQuery = query
    }
  }
  
  var stories = [FoodieStory]() {
    didSet {
      feedCollectionViewController?.storyArray = stories
      feedCollectionViewController?.reloadData()
    }
  }
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var navBar: UINavigationBar!
  @IBOutlet weak var feedContainerView: UIView!
  
  
  // MARK: - IBAction
  @IBAction func backAction(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }
  
  
  @IBAction func logOutAction(_ sender: UIBarButtonItem) {
    LogOutDismiss.askDiscardIfNeeded(from: self)
  }
  
  
  @IBAction func settingsAction(_ sender: UIBarButtonItem) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of SettingsViewController Class!!")
      }
      return
    }
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
    
//    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
//
//    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsTableViewController") as? SettingsTableViewController else {
//      CCLog.fatal("Cannot cast ViewController from Storyboard to SettingsTableViewController")
//    }
//    let navController = SettingsNavController(rootViewController: viewController)
//    self.present(navController, animated: true)
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    navBar.delegate = self
    
    guard let user = user, user.isRegistered else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Entered Profile View but no valid registered user specified")
        self.dismiss(animated: true, completion: nil)
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
    
    let activitySpinner = ActivitySpinner(addTo: view)
    activitySpinner.apply()
    
    // Actually do the Query
    query!.initStoryQueryAndSearch { (stories, error) in
      activitySpinner.remove()
      
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
    
    // Setup a Feed VC into the Container View
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "FeedCollectionViewController") as? FeedCollectionViewController else {
      CCLog.fatal("Cannot cast FeedCollectionViewController from Storyboard to FeedCollectionViewController")
    }
    viewController.storyQuery = query
    viewController.storyArray = stories
    viewController.scrollViewInset = navBar.frame.height
    
    addChildViewController(viewController)
    feedContainerView.addSubview(viewController.view)
    viewController.view.frame = feedContainerView.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParentViewController: self)
    feedCollectionViewController = viewController
  }
  
  
}


extension ProfileViewController: UINavigationBarDelegate {
  func position(for bar: UIBarPositioning) -> UIBarPosition {
    return UIBarPosition.topAttached
  }
}
