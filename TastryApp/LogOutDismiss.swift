//
//  LogOutDismiss.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


struct LogOutDismiss {
  
  // MARK: - Public Static Functions
  
  static func askDiscardIfNeeded(from viewController: UIViewController) {
    if FoodieStory.currentStory != nil {
      AlertDialog.presentConfirm(from: viewController, title: "Log Out", message: "Are you sure you want to log out? You will lose your unsaved draft if you log out") { _ in
        self.logOutAndDismiss(from: viewController)
      }
    } else {
      AlertDialog.presentConfirm(from: viewController, title: "Log Out", message: "Are you sure you want to log out?") { _ in
        self.logOutAndDismiss(from: viewController)
      }
    }
  }
  
  

  // MARK: - Private Instance Functions
  
  private static func logOutAndDismiss(from viewController: UIViewController) {
    
    let activitySpinner = ActivitySpinner(addTo: viewController.view, blurStyle: .dark, spinnerStyle: .whiteLarge)
    activitySpinner.apply()
    
    FoodieUser.logOutAndDeleteDraft { error in
      activitySpinner.remove()
      if let error = error {
        AlertDialog.present(from: viewController, title: "Log Out Error", message: error.localizedDescription) { _ in
          CCLog.assert("Log Out Failed - \(error.localizedDescription)")
        }
      }
      
      if let navigationController = viewController.navigationController {
        navigationController.popToRootViewController(animated: false)
      }
      
      // Proceed to dismiss regardless
      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let window = appDelegate.window, let rootViewController = window.rootViewController else {
        AlertDialog.standardPresent(from: viewController, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Cannot get AppDelegate.window.rootViewController!!!!")
        }
        return
      }
      
      // Animated dismissal of 2+ VCs is super weird. So no.
      rootViewController.dismiss(animated: false, completion: nil)
    }
  }
}
