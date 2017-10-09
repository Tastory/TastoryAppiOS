//
//  StoryCompositionViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class StoryCompositionViewController: TransitableViewController {
  
  var staticTableViewController: StoryEntryViewController?
  
  var workingStory: FoodieStory? {
    didSet {
      staticTableViewController?.workingStory = workingStory
    }
  }
  
  var returnedMoment: FoodieMoment? {
    didSet {
      staticTableViewController?.returnedMoment = returnedMoment
    }
  }
  
  var markupMoment: FoodieMoment? {
    didSet {
      staticTableViewController?.markupMoment = markupMoment
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
      }
      return
    }
    
    viewController.workingStory = workingStory
    viewController.returnedMoment = returnedMoment
    viewController.markupMoment = markupMoment
    viewController.containerVC = self
    
    addChildViewController(viewController)
    view.addSubview(viewController.view)
    viewController.view.frame = view.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParentViewController: self)
    staticTableViewController = viewController
  }
}

extension StoryCompositionViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedStory: FoodieStory?) {
    self.returnedMoment = markedupMoment
    self.markupMoment = markedupMoment
    dismiss(animated: true, completion: nil)
  }
}
