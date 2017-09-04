//
//  RootViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
  
  // MARK: - Public Instance Variables
  var startupError: Error? = nil
  
  
  // MARK: - Private Static Functions
  fileprivate func offlineErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "Unable to Access Network",
                                              titleComment: "Alert diaglogue title when unable to access network on startup",
                                              message: "Offline Mode is coming soon! Sorry for the inconvinience.",
                                              messageComment: "Alert diaglogue message when unable to access network on startup",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box when unable to access network on startup",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    CCLog.info("Main Thread ID Checkpoint")
  }
  
  override func viewDidAppear(_ animated: Bool) {
    
    if let error = startupError as? FoodieGlobal.ErrorCode, error == .startupFoursquareCategoryError {
      offlineErrorDialog()
    } else {
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController")
      self.present(viewController, animated: true)
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("RootViewController.didReceiveMemoryWarning")
  }
}
