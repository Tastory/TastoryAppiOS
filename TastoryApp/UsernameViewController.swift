//
//  UsernameViewController
//  TastoryApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

class UsernameViewController: OverlayViewController {
  
  // MARK: - IBOutlet
  @IBOutlet var usernameField: UITextField!
  
  
  // MARK: - IBAction
  @IBAction func okAction(_ sender: UIButton) {
    
    guard let user = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Current User just after Signup")
      }
      return
    }
    
    guard var username = usernameField.text else {
      AlertDialog.present(from: self, title: "No Username", message: "Please enter a username")
      CCLog.warning("usernameField.text = nil")
      return
    }
    
    // Okay, lower case usernames only.
    username = username.lowercased()
    usernameField.text = username

    // Check for validity and availability before allowing to save
    if let error = FoodieUser.checkValidFor(username: username) {
      AlertDialog.present(from: self, title: "Invalid Username", message: "\(error.localizedDescription)")
      CCLog.info("User entered invalid username - \(error.localizedDescription)")
      return
    }
    
    ActivitySpinner.globalApply()
    
    FoodieUser.checkUserAvailFor(username: username) { (usernameSuccess, usernameError) in

      if let usernameError = usernameError {
        AlertDialog.present(from: self, title: "Change Failed", message: "Unable to check Username Validity")
        CCLog.warning("checkUserAvailFor username: (\(username)) Failed - \(usernameError.localizedDescription)")
        ActivitySpinner.globalRemove()
        return
        
      } else if !usernameSuccess {
        AlertDialog.present(from: self, title: "Unavailable", message: "Username \(username) already taken")
        CCLog.info("checkUserAvailFor username: (\(username)) already exists")
        ActivitySpinner.globalRemove()
        return
      }
      
      user.username = username
      
      _ = user.saveDigest(to: .both, type: .cache) { error in
        ActivitySpinner.globalRemove()
        if let error = error {
          AlertDialog.present(from: self, title: "Change Failed", message: "Error - \(error.localizedDescription). Please try again") { _ in
            CCLog.warning("saveDigest Failed. Error - \(error.localizedDescription)")
          }
          return
        }
        
        // User is all signed up now!
        let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
        
        guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "IntroViewController") as? IntroViewController else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("ViewController initiated not of IntroViewController Class!!")
          }
          return
        }
        
        viewController.firstLabelText = "Thanks for Signing Up!"
        viewController.secondLabelText = "Go ahead, drool over the Tasty Stories around you~"
        viewController.enableResend = false
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: false)
        self.pushPresent(viewController, animated: true)
      }
    }
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
}
