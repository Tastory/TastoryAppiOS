//
//  DiscoverFeedViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class DiscoverFeedViewController: OverlayViewController {
 
  // MARK: - Private Instance Variables
  var storyArray: [FoodieStory]?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let stories = storyArray else {
      CCLog.fatal("No Stories when loading DiscoverFeedViewController")
    }
    
    let nodeController = FeedCollectionNodeController()
    nodeController.storyArray = stories
    addChildViewController(nodeController)
    view.addSubview(nodeController.view)
    nodeController.view.frame = view.bounds
    nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    nodeController.didMove(toParentViewController: self)
  }
}
