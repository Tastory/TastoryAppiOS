//
//  LogInViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class LogInViewController: UIViewController {
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var titleLabel: UILabel!
  
  @IBOutlet weak var usernameField: UITextField!
  
  @IBOutlet weak var passwordField: UITextField!
  
  @IBOutlet weak var logInButton: UIButton!
  
  @IBOutlet weak var signUpButton: UIButton!
  
  @IBOutlet weak var forgotButton: UIButton!
  
  @IBOutlet weak var facebookButton: UIButton!
  
  
  
  // MARK: - IBAction
  @IBAction func logInAction(_ sender: UIButton) {
    
    guard let logInText = usernameField.text else {
      AlertDialog.present(from: self, title: "Log In Error", message: "Please enter your Username or E-mail address to log in") { action in
        CCLog.info("No username when Log In pressed")
      }
      return
    }
    
    guard let password = passwordField.text else {
      AlertDialog.present(from: self, title: "Log In Error", message: "Please enter you Password to log in") { action in
        CCLog.info("No password when Log In pressed")
      }
      return
    }
    
    // If the username looks like a valid E-mail, there's no way it can be a regular username
    if FoodieUser.checkValidFor(email: logInText) {
      FoodieUser.getUserFor(email: logInText) { (object, error) in
        if let error = error {
          CCLog.warning("Error trying to get user for \(logInText) - \(error.localizedDescription)")
          AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain)
          return
        }
        
        guard let user = object as? FoodieUser else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Nil returned from getting user for \(logInText). Expected Foodie User object")
          }
          return
        }
        
        guard let username = user.username else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Refurned FoodieUser for \(logInText) does not contain a username")
          }
          return
        }
        
        // So we got a proper user through the E-mail. Log In via the username
        self.logIn(for: username, using: password)
      }
      
    } else {
      // Tread the Log In text as Username and try to Log In
      logIn(for: logInText, using: password)
    }
  }
  
  
  @IBAction func signUpAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SignUpViewController") as? SignUpViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of SignUpViewController Class!!")
      }
      return
    }
    
    viewController.username = usernameField.text
    viewController.password = passwordField.text
    self.present(viewController, animated: true)
  }
  
  
  @IBAction func forgotAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "EmailResetViewController") as? EmailResetViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of EmailResetViewController Class!!")
      }
      return
    }
    
    if let logInText = usernameField.text, FoodieUser.checkValidFor(email: logInText) {
      viewController.emailAddress = logInText
    }
    self.present(viewController, animated: true)
  }
  
  
  @IBAction func facebookAction(_ sender: UIButton) {
    CCLog.warning("Facebook Login To Be Implemented")
  }
  
  
  @IBAction func guestLogInAction(_ sender: UIButton) {
    // Force a log-out if there is a user logged-in
    if FoodieUser.current != nil {
      FoodieUser.logOutAndDeleteDraft(withBlock: nil)
    }
    
    AlertDialog.present(from: self, title: "Guest Login", message: "You will not be able to post as a Guest. We highly encourage you to sign-up and log-in for the best experience!") { action in
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MapViewController")
      self.present(viewController, animated: true)
    }
  }
  
  
  @IBAction func tapGestureAction(_ sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
  
  
  
  // MARK: - Private Instance Function
  private func logIn(for username: String, using password: String) {
    
    view.endEditing(true)
    
    let blurSpinner = BlurSpinWait()
    blurSpinner.apply(to: self.view, blurStyle: .dark, spinnerStyle: .whiteLarge)
    
    FoodieUser.logIn(for: username, using: password) { (user, error) in
      
      blurSpinner.remove()
      
      if let error = error {
        AlertDialog.present(from: self, title: "Login Failed", message: error.localizedDescription) { action in
          CCLog.warning("Login with \(username) failed - \(error.localizedDescription)")
        }
        return
      }
      
      guard let user = user else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Nil returned from getting user for \(username). Expected Foodie User object")
        }
        return
      }
      
      self.presentLogIn(for: user, withWelcome: true)
    }
  }
  
  
  private func presentLogIn(for user: FoodieUser, withWelcome welcome: Bool) {
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "IntroViewController") as? IntroViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of IntroViewController Class!!")
      }
      return
    }
    
    user.checkIfEmailVerified { (verified, error) in
      DispatchQueue.main.async {
        if let error = error {
          AlertDialog.present(from: self, title: "Email Status Error", message: error.localizedDescription) { action in
            CCLog.warning("Error getting E-mail Status - \(error.localizedDescription)")
          }
        } else if verified {
          if welcome {
            viewController.firstLabelText = "Welcome Back~"
            if let fullName = user.fullName {
              viewController.secondLabelText = fullName + "!"
            } else if let username = user.username {
              viewController.secondLabelText = username + "!"
            } else {
              CCLog.fatal("No username for FoodieUser!!")
            }
            viewController.enableResend = false
          }
        } else {
          viewController.firstLabelText = "It seems you have not verified your E-mail. You will not be able to post"
          viewController.secondLabelText = "For now, you can start by checking out what Tasty Stories are around you~"
          viewController.enableResend = true
        }
        
        self.present(viewController, animated: true, completion: nil)
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    facebookButton.layer.cornerRadius = 5.0
    
    // Gonna wipe all previous user state if you ever get here
    if FoodieStory.currentStory != nil {
      FoodieStory.removeCurrent()
    }
  }

  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
  
}
