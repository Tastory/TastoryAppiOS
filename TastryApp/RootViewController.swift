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
    if let currentUser = FoodieUser.current, currentUser.isRegistered {
      
      _ = currentUser.retrieveRecursive(from: .both, type: .cache, forceAnyways: true) { error in
        if let error = error {
          CCLog.warning("Retrieve latest copy of Current User failed with Error - \(error.localizedDescription)")
        }
        
        // Make sure the right permissions are assigned to objects since we are assuming a User
        FoodiePermission.setDefaultObjectPermission(for: currentUser)
      }
      
      // Risking it by jumping to the Main View in parallel with updating the user's details from server
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController") as? DiscoverViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of DiscoverViewController Class!!")
        }
        return
      }
      let mapNavController = MapNavController(rootViewController: viewController)
      self.present(mapNavController, animated: false, completion: nil)
      
    } else {
      // Resetting permissions back to global default since we don't know whose gonna be logged'in
      FoodiePermission.setDefaultGlobalObjectPermission()
      
      // Jump to the Login/Signup Screen!
      let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "LogInViewController") as? LogInViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of LogInViewController Class!!")
        }
        return
      }
      viewController.setSlideTransition(presentTowards: .left, withGapSize: 5.0, dismissIsInteractive: false)
      self.present(viewController, animated: false)
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}
