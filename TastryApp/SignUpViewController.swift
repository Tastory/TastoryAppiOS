//
//  SignUpViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class SignUpViewController: TransitableViewController {
  
  
  // MARK: - Public Instance Variable
  
  var username: String?
  var password: String?
  
  
  
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
    dismiss(animated: true, completion: nil)
  }
  
  
  @IBAction func tapGestureAction(_ sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
  
  
  
  // MARK: - Private Static Functions
  fileprivate func signUp() {
    guard let username = usernameField.text else {
      AlertDialog.present(from: self, title: "Username Empty", message: "Please enter a username to sign up") { action in
        CCLog.info("No username when Sign Up pressed")
      }
      return
    }
    
    guard let email = emailField.text else {
      AlertDialog.present(from: self, title: "E-mail Empty", message: "Please enter a valid e-mail address to sign up") { action in
        CCLog.info("No e-mail address when Sign Up pressed")
      }
      return
    }
    
    guard let password = passwordField.text else {
      AlertDialog.present(from: self, title: "Password Empty", message: "Please enter a password to sign up") { action in
        CCLog.info("No password when Sign Up pressed")
      }
      return
    }
    
    let user = FoodieUser()
    user.username = username
    user.email = email
    user.password = password
    
    let blurSpinner = BlurSpinWait()
    blurSpinner.apply(to: view, blurStyle: .dark, spinnerStyle: .whiteLarge)
    
    // Don't bother with checking whether things are available. Sign-up to find out
    // SignUp also checks for username/e-mail/password validity
    user.signUp { error in
      blurSpinner.remove()
      
      // Handle all known error cases
      if let error = error {
        AlertDialog.present(from: self, title: "Sign Up Failed", message: "\(error.localizedDescription)") { action in
          CCLog.info("Sign Up Failed - \(error.localizedDescription)")
        }
      } else {
        let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
        
        guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "IntroViewController") as? IntroViewController else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("ViewController initiated not of IntroViewController Class!!")
          }
          return
        }
        
        viewController.firstLabelText = "Please make sure you confirm your E-mail so you can start posting"
        viewController.secondLabelText = "For now, you can start by checking out what Tasty Stories are around you~"
        viewController.enableResend = false
        self.present(viewController, animated: true)
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    usernameField.delegate = self
    emailField.delegate = self
    passwordField.delegate = self
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    usernameField.becomeFirstResponder()
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}



// MARK: - Protocol Conformance for UITextFieldDelegate

extension SignUpViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    
    switch textField {
    case usernameField:
      warningLabel.text = ""
      guard let textString = textField.text, textString.characters.count >= FoodieUser.Constants.MinUsernameLength else {
        return  // No text, nothing to see here
      }
      
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
      guard let textString = textField.text, textString.characters.count >= FoodieUser.Constants.MinEmailLength else {
        return  // No yet an E-mail, nothing to see here
      }
      
//      if !FoodieUser.checkValidFor(email: textString) {
//        warningLabel.text = "Address entered is not of valid E-mail address format"
//        return
//      }
      
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
      guard let textString = textField.text, textString.characters.count >= FoodieUser.Constants.MinPasswordLength else {
        return  // Not yet a password, nothing to see here
      }
      
      if let error = FoodieUser.checkValidFor(password: textString, username: usernameField.text, email: emailField.text) {
        warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
    
    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("There is no other text fields in this switch-case")
      }
    }
    return true
  }
}


