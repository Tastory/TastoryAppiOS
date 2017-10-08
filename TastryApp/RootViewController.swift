//
//  RootViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Tastry. All rights reserved.
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
      if let currentUser = FoodieUser.current, currentUser.isRegistered {
        
        // Get an updated copy of User before proceeding
        currentUser.retrieve(forceAnyways: true) { error in
          if let error = error {
            CCLog.warning("Retrieve latest copy of Current User failed with Error - \(error.localizedDescription)")
          }
          
          // Make sure the right permissions are assigned to objects since we are assuming a User
          FoodiePermission.setDefaultObjectPermission(for: currentUser)
          
          // Lets just jump directly into the Main view!
          let storyboard = UIStoryboard(name: "Main", bundle: nil)
          let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MapViewController")
          self.present(viewController, animated: false, completion: nil)
        }
      } else {
        // Resetting permissions back to global default since we don't know whose gonna be logged'in
        FoodiePermission.setDefaultGlobalObjectPermission()
        
        // Jump to the Login/Signup Screen!
        let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
        let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "LogInViewController")
        self.present(viewController, animated: false)
      }
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}
