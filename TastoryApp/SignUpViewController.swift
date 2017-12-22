//
//  SignUpViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit

class SignUpViewController: OverlayViewController {
  
  
  // MARK: - Public Instance Variable
  
  var username: String?
  var password: String?
  
  
  
  // MARK: - Private Instance Variable
  
  private var activitySpinner: ActivitySpinner!
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var titleLabel: UILabel!
  
  @IBOutlet weak var usernameField: UITextField! {
    didSet {
      usernameField.text = username
    }
  }
  
  @IBOutlet weak var emailField: UITextField!
  
  @IBOutlet weak var passwordField: UITextField! {
    didSet {
      passwordField.text = password
    }
  }
  
  @IBOutlet weak var hideShowPwdButton: UIButton!
  
  @IBOutlet weak var warningLabel: UILabel!
  
  
  
  // MARK: - IBAction
  
  @IBAction func signUpAction(_ sender: UIButton) {
    signUp()
  }
  
  
  @IBAction func hideShowPwdAction(_ sender: UIButton) {
    if passwordField.isSecureTextEntry {
      passwordField.isSecureTextEntry = false
      hideShowPwdButton.setTitle("Hide", for: .normal)
      hideShowPwdButton.setTitleColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), for: .normal)
    } else {
      passwordField.isSecureTextEntry = true
      hideShowPwdButton.setTitle("Show", for: .normal)
      hideShowPwdButton.setTitleColor(UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0), for: .normal)
    }
  }
  
  
  @IBAction func exitAction(_ sender: UIButton) {
    view.endEditing(true)
    popDismiss(animated: true)
  }
  
  
  @IBAction func tapGestureAction(_ sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
  
  
  
  // MARK: - Private Static Functions
  fileprivate func signUp() {
    guard var username = usernameField.text else {
      AlertDialog.present(from: self, title: "Username Empty", message: "Please enter a username to sign up") { _ in
        CCLog.info("No username when Sign Up pressed")
      }
      return
    }
    
    guard var email = emailField.text else {
      AlertDialog.present(from: self, title: "E-mail Empty", message: "Please enter a valid e-mail address to sign up") { _ in
        CCLog.info("No e-mail address when Sign Up pressed")
      }
      return
    }
    
    guard let password = passwordField.text else {
      AlertDialog.present(from: self, title: "Password Empty", message: "Please enter a password to sign up") { _ in
        CCLog.info("No password when Sign Up pressed")
      }
      return
    }
    
    // Okay, lower case username and E-mail only.
    username = username.lowercased()
    usernameField.text = username
    email = email.lowercased()
    emailField.text = email
    
    let user = FoodieUser()
    user.username = username
    user.email = email
    user.password = password
    
    activitySpinner.apply()
    
    // Don't bother with checking whether things are available. Sign-up to find out
    // SignUp also checks for username/e-mail/password validity
    user.signUp { error in
      self.activitySpinner.remove()
      
      // Handle all known error cases
      if let error = error {
        Analytics.logSignupEvent(method: .email, success: false, note: error.localizedDescription)
        
        AlertDialog.present(from: self, title: "Sign Up Failed", message: "\(error.localizedDescription)") { _ in
          CCLog.info("Sign Up Failed - \(error.localizedDescription)")
        }
      } else {
        Analytics.logSignupEvent(method: .email, success: true, note: "")
        
        let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
        
        guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "IntroViewController") as? IntroViewController else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("ViewController initiated not of IntroViewController Class!!")
          }
          return
        }
        
        viewController.firstLabelText = "Please make sure you confirm your E-mail so you can start posting"
        viewController.secondLabelText = "For now, you can start by checking out what Tasty Stories are around you~"
        viewController.enableResend = false
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: false)
        self.pushPresent(viewController, animated: true)
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    usernameField.delegate = self
    emailField.delegate = self
    passwordField.delegate = self
    
    activitySpinner = ActivitySpinner(addTo: view)
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    usernameField.becomeFirstResponder()
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
}



// MARK: - Protocol Conformance for UITextFieldDelegate

extension SignUpViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    
    switch textField {
    case usernameField:
      warningLabel.text = ""
      guard var textString = textField.text, textString.count >= FoodieUser.Constants.MinUsernameLength else {
        return  // No text, nothing to see here
      }
      
      // Okay. Lower cased usernames only
      textString = textString.lowercased()
      textField.text = textString
      
      if let error = FoodieUser.checkValidFor(username: textString) {
        warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
      
      FoodieUser.checkUserAvailFor(username: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor username: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.warningLabel.text = "✖︎ " + "Username '\(textString)' is not available"
          }
        }
      }
      
    case emailField:
      warningLabel.text = ""
      guard var textString = textField.text, textString.count >= FoodieUser.Constants.MinEmailLength else {
        return  // No yet an E-mail, nothing to see here
      }
      
      // Lower cased emails only too
      textString = textString.lowercased()
      textField.text = textString
      
      FoodieUser.checkUserAvailFor(email: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor E-mail: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.warningLabel.text = "✖︎ " + "E-mail address \(textString) is already signed up"
          }
        }
      }
      
    case passwordField:
      warningLabel.text = ""
      guard let textString = textField.text, textString.count >= FoodieUser.Constants.MinPasswordLength else {
        return  // Not yet a password, nothing to see here
      }
      
      if let error = FoodieUser.checkValidFor(password: textString, username: usernameField.text, email: emailField.text) {
        warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
    
    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("There is no other text fields in this switch-case")
      }
    }
  }
  
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    switch textField {
    case usernameField:
      emailField.becomeFirstResponder()
    case emailField:
      passwordField.becomeFirstResponder()
    case passwordField:
      passwordField.resignFirstResponder()
      signUp()
    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("There is no other text fields in this switch-case")
      }
    }
    return true
  }
}


