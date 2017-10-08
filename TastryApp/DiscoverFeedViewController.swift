//
//  DiscoverFeedViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class DiscoverFeedViewController: TransitableViewController {
  
  // MARK: - Private Instance Variables
  private var feedCollectionViewController: FeedCollectionViewController?
  
  
  // MARK: - Public Instance Variable
  var storyQuery: FoodieQuery! {
    didSet {
      feedCollectionViewController?.storyQuery = storyQuery
    }
  }
  
  var storyArray = [FoodieStory]() {
    didSet {
      feedCollectionViewController?.storyArray = storyArray
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "FeedCollectionViewController") as? FeedCollectionViewController else {
      CCLog.fatal("Cannot cast FeedCollectionViewController from Storyboard to FeedCollectionViewController")
    }
    
    viewController.storyQuery = storyQuery
    viewController.storyArray = storyArray
    
    addChildViewController(viewController)
    view.addSubview(viewController.view)
    viewController.view.frame = view.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParentViewController: self)
    feedCollectionViewController = viewController
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}
