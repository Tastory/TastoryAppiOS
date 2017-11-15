//
//  StoryCompositionViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class StoryCompositionViewController: OverlayViewController {
  
  var staticTableViewController: StoryEntryViewController?

  var restoreStoryDelegate: RestoreStoryDelegate? {
    didSet {
      staticTableViewController?.restoreStoryDelegate = restoreStoryDelegate
    }
  }

  var workingStory: FoodieStory? {
    didSet {
      staticTableViewController?.workingStory = workingStory
    }
  }
  
  var returnedMoments: [FoodieMoment] = [] {
    didSet {
      staticTableViewController?.returnedMoments = returnedMoments
    }
  }
  
  var markupMoment: FoodieMoment? {
    didSet {
      staticTableViewController?.markupMoment = markupMoment
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
      }
      return
    }
    
    viewController.workingStory = workingStory
    viewController.returnedMoments = returnedMoments
    viewController.markupMoment = markupMoment
    viewController.containerVC = self
    viewController.parentNavController = navigationController
    viewController.restoreStoryDelegate = restoreStoryDelegate
    
    addChildViewController(viewController)
    view.addSubview(viewController.view)
    viewController.view.frame = view.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParentViewController: self)
    staticTableViewController = viewController
  }
}

extension StoryCompositionViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    self.returnedMoments = markedupMoments

    if(markedupMoments.count > 0) {
      self.markupMoment = markedupMoments.first
    }
    dismiss(animated: true, completion: nil)  // This dismiss is for the MarkupVC to call, not for the Story Composition VC
  }
}
