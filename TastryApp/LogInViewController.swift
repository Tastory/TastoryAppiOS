//
//  LogInViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import SafariServices

class LogInViewController: OverlayViewController {
  
  
  // MARK: - Private Instance Variable
  private var activitySpinner: ActivitySpinner! // Initialize in ViewDidLoad
  
  
  
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
    
    guard var logInText = usernameField.text else {
      AlertDialog.present(from: self, title: "Log In Error", message: "Please enter your Username or E-mail address to log in") { _ in
        CCLog.info("No username when Log In pressed")
      }
      return
    }
    
    guard let password = passwordField.text else {
      AlertDialog.present(from: self, title: "Log In Error", message: "Please enter you Password to log in") { _ in
        CCLog.info("No password when Log In pressed")
      }
      return
    }
    
    // Enforce lower case
    logInText = logInText.lowercased()
    usernameField.text = logInText
    
    // If the username looks like a valid E-mail, there's no way it can be a regular username
    if FoodieUser.checkValidFor(email: logInText) {
      FoodieUser.getUserFor(email: logInText) { (object, error) in
        if let error = error {
          CCLog.warning("Error trying to get user for \(logInText) - \(error.localizedDescription)")
          AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain)
          return
        }
        
        guard let user = object as? FoodieUser else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            CCLog.assert("Nil returned from getting user for \(logInText). Expected Foodie User object")
          }
          return
        }
        
        guard let username = user.username else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            CCLog.assert("Returned FoodieUser for \(logInText) does not contain a username")
          }
          return
        }
        
        // So we got a proper user through the E-mail. Log In via the username
        self.logIn(for: username, using: password)
      }
      
    } else {
      // Treat the Log In text as Username and try to Log In
      logIn(for: logInText, using: password)
    }
  }
  
  
  @IBAction func signUpAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SignUpViewController") as? SignUpViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of SignUpViewController Class!!")
      }
      return
    }
    
    viewController.username = usernameField.text
    viewController.password = passwordField.text
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func forgotAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "EmailResetViewController") as? EmailResetViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of EmailResetViewController Class!!")
      }
      return
    }
    
    if let logInText = usernameField.text, FoodieUser.checkValidFor(email: logInText) {
      viewController.emailAddress = logInText
    }
    viewController.setSlideTransition(presentTowards: .up, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func facebookAction(_ sender: UIButton) {
    view.endEditing(true)
    activitySpinner.apply()
    
    FoodieUser.facebookLogIn() { (user, error) in
      self.activitySpinner.remove()
      
      if let error = error {
        // Do not show Alert Dialog for Error related to Cancel. This is the iOS 11 case
        if #available(iOS 11.0, *),
          let sfError = error as? SFAuthenticationError,
          sfError.errorCode == SFAuthenticationError.Code.canceledLogin.rawValue {
            
          CCLog.info("Facebook login cancelled")
          if FoodieUser.current != nil { FoodieUser.logOut() }
          return
        }
        
        // Do not show Alert Dialog for Error related to Cancel. This is the iOS 10 case
        if let foodieError = error as? FoodieUser.ErrorCode {
          switch foodieError {
          case .facebookLoginFoodieUserNil:
            CCLog.info("Facebook login cancelled")
            if FoodieUser.current != nil { FoodieUser.logOut() }
            return
            
          default:
            break
          }
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.6) {
          AlertDialog.present(from: self, title: "FB Login Failed", message: error.localizedDescription) { _ in
            CCLog.warning("Facebook login failed - \(error.localizedDescription)")
          }
        }
        
        Analytics.logLoginEvent(method: .facebook, success: false, note: error.localizedDescription)
        if FoodieUser.current != nil { FoodieUser.logOut() }
        return
      }
      
      guard let user = user else {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.6) {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            CCLog.assert("Nil returned from getting user for Facebook Login. Expected Foodie User object")
          }
        }
        
        Analytics.logLoginEvent(method: .facebook, success: false, note: "No User Returned")
        if FoodieUser.current != nil { FoodieUser.logOut() }
        return
      }
      
      if user.isNew {
        Analytics.logSignupEvent(method: .facebook, success: true, note: "")
        
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
        
      } else {
        
        Analytics.logLoginEvent(method: .facebook, success: true, note: "")
        self.presentLogIn(for: user, withWelcome: true)
      }
    }
  }
  
  
  @IBAction func guestLogInAction(_ sender: UIButton) {
    // Force a log-out if there is a user logged-in
    if FoodieUser.current != nil {
      FoodieUser.logOutAndDeleteDraft(withBlock: nil)
    }
    
    AlertDialog.present(from: self, title: "Guest Login", message: "You will not be able to post as a Guest. We highly encourage you to sign-up and log-in for the best experience!") { [unowned self] _ in
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController") as? DiscoverViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("ViewController initiated not of DiscoverViewController Class!!")
        }
        return
      }
      let mapNavController = MapNavController(rootViewController: viewController)
      mapNavController.modalTransitionStyle = .crossDissolve
      self.present(mapNavController, animated: true)
    }
  }
  
  
  @IBAction func tapGestureAction(_ sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
  
  
  
  // MARK: - Private Instance Function
  private func logIn(for username: String, using password: String) {
    
    view.endEditing(true)
    activitySpinner.apply()
    
    FoodieUser.logIn(for: username, using: password) { (user, error) in
      self.activitySpinner.remove()
      
      let loginSuccess = (error != nil && user != nil)
      let loginErrorNote = error?.localizedDescription ?? ""
      Analytics.logLoginEvent(method: .email, success: loginSuccess, note: loginErrorNote)
      
      if let error = error {
        AlertDialog.present(from: self, title: "Login Failed", message: error.localizedDescription) { _ in
          CCLog.warning("Login with \(username) failed - \(error.localizedDescription)")
        }
        return
      }
      
      guard let user = user else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of IntroViewController Class!!")
      }
      return
    }
    
    user.checkIfEmailVerified { (verified, error) in
      DispatchQueue.main.async {
        
        if verified {
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
        }
        
        else {
          if let error = error {
            AlertDialog.present(from: self, title: "Email Status Error", message: error.localizedDescription) { _ in
              CCLog.warning("Error getting E-mail Status - \(error.localizedDescription)")
            }
          }
          viewController.firstLabelText = "It seems you have not verified your E-mail. You will not be able to post"
          viewController.secondLabelText = "For now, you can start by checking out what Tasty Stories are around you~"
          viewController.enableResend = true
        }
        
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: false)
        self.pushPresent(viewController, animated: true)
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    facebookButton.layer.cornerRadius = 5.0
    activitySpinner = ActivitySpinner(addTo: view, blurStyle: .prominent)
    
    // Gonna wipe all previous user state if you ever get here
    if FoodieStory.currentStory != nil {
      FoodieStory.removeCurrent()
    }
  }

  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
}


extension LogInViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    switch textField {
    case usernameField:
      passwordField.becomeFirstResponder()
    case passwordField:
      passwordField.resignFirstResponder()
      logInAction(logInButton)
    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("There is no other text fields in this switch-case")
      }
    }
    return true
  }
}
