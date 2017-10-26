//
//  PasswordTableViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class PasswordTableViewController: UITableViewController {
  
  // MARK: - Constants
  
  struct Constants {
    static let SaveFooterHeight: CGFloat = 80.0
    static let EmptyFooterHeight: CGFloat = 50.0
  }
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var currentField: UITextField? {
    didSet {
      currentField!.delegate = self
    }
  }
  
  @IBOutlet weak var newField: UITextField? {
    didSet {
      newField!.delegate = self
    }
  }
  
  @IBOutlet weak var confirmField: UITextField? {
    didSet {
      confirmField!.delegate = self
    }
  }
  
  
  
  // MARK: - Private Instance Variable
  private var activitySpinner: ActivitySpinner!
  private var saveFooterView: PasswordTableSaveFooterView!

  
  
  // MARK: - Public Instance Variable
  var user: FoodieUser!
  
  
  
  // MARK: - Private Instance Functions
  @objc private func changePassword() {
    
    guard let username = user.username, let email = user.email else {
      CCLog.fatal("User with no username or no E-mail address")
    }
    
    self.saveFooterView.warningLabel?.text = ""
    
    view.endEditing(true)
    
    // Check all the fields for validity first first
    guard let currentText = currentField?.text else {
      AlertDialog.present(from: self, title: "Password Empty", message: "You must enter the current password to perform a password change")
      return
    }
    
    guard let newText = newField?.text else {
      AlertDialog.present(from: self, title: "Password Empty", message: "You must enter a new password to perform a password change")
      return
    }
    
    guard let confirmText = confirmField?.text, confirmText == newText else {
      AlertDialog.present(from: self, title: "Password Mismatch", message: "Your new password and confirmation does not match")
      return
    }
    
    guard newText != currentText else {
      AlertDialog.present(from: self, title: "Invalid Password", message: "Your new Password is same as what's entered in Current")
      return
    }
    
    if let error = FoodieUser.checkValidFor(password: newText, username: username, email: email) {
      AlertDialog.present(from: self, title: "Invalid Password", message: error.localizedDescription)
      return
    }
    
    CCLog.info("Attempting to Log-in in-order to verify entered password")
    
    activitySpinner.apply()
    
    // So all the field passes. Let's see if the old password is correct by re-login
    FoodieUser.logIn(for: username, using: currentText) { _, error in
      
      if let error = error {
        AlertDialog.present(from: self, title: "Password Change Failed", message: "\(error.localizedDescription). Please try again")
        CCLog.info("Login for password confirmation with \(username) failed - \(error.localizedDescription)")
        self.activitySpinner.remove()
        return
      }
      
      // Everything checks out. Change the password
      self.user.password = newText
      
      // Save the user
      self.user.saveRecursive(to: .both, type: .cache) { error in
        self.activitySpinner.remove()
        
        if let error = error {
          AlertDialog.present(from: self, title: "Save New Password Failed", message: "Error - \(error.localizedDescription). Please try again") { action in
            CCLog.warning("user.saveRecursive Failed. Error - \(error.localizedDescription)")
          }
          return
        }
        
        // Clear all text fields
        self.currentField?.text = ""
        self.newField?.text = ""
        self.confirmField?.text = ""
        
        // Notify the user that password change was successful
        AlertDialog.present(from: self, title: "Password Changed!", message: "Password change was successful!") { action in
          self.navigationController?.popViewController(animated: true)
        }
      }
    }
  }
  
  
  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let saveFooterNib = UINib(nibName: "PasswordTableSaveFooterView", bundle: nil)
    guard let saveFooterView = saveFooterNib.instantiate(withOwner: self, options: nil)[0] as? PasswordTableSaveFooterView else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Cannot create PasswordTableSaveFooterView from Nib")
      }
      return
    }
    self.saveFooterView = saveFooterView
    
    // Set Default UI
    self.saveFooterView.changeButton.addTarget(self, action: #selector(changePassword), for: .touchUpInside)
    self.saveFooterView.saveFooterHeight = Constants.SaveFooterHeight
    self.saveFooterView.warningLabel.text = ""
    
    activitySpinner = ActivitySpinner(addTo: view)
    
    // Add a Tap gesture recognizer to dismiss the keyboard when needed
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGestureRecognizer.numberOfTapsRequired = 1
    tapGestureRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(tapGestureRecognizer)
    
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("We are only supporting Password Change for Current User only")
    }
    user = currentUser
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
  
  
  
  // MARK: - Table View Data Source
  
  override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    if section == 0 {
      return saveFooterView
    } else {
      return nil
    }
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    if section == 0 {
      return saveFooterView.saveFooterHeight
    } else {
      return Constants.EmptyFooterHeight
    }
  }
  
  override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
    if section == 0 {
      return saveFooterView.saveFooterHeight
    } else {
      return Constants.EmptyFooterHeight
    }
  }
}



extension PasswordTableViewController: UITextFieldDelegate {
  
  func textFieldDidEndEditing(_ textField: UITextField) {

    guard let username = user.username, let email = user.email else {
      CCLog.fatal("User with no username or no E-mail address")
    }
    
    self.saveFooterView.warningLabel.text = ""
    
    guard let textString = textField.text else {
      return  // Nothing entered
    }
    
    switch textField {
    case currentField!:
      if let confirm = confirmField?.text, textString == confirm {
        self.saveFooterView.warningLabel.text = "✖︎ " + "New Password same as what's entered in Current"
        return
      }
      
    case newField!:
      if let error = FoodieUser.checkValidFor(password: textString, username: username, email: email) {
        self.saveFooterView.warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
      
      if let current = currentField?.text, textString == current {
        self.saveFooterView.warningLabel.text = "✖︎ " + "New Password same as what's entered in Current"
        return
      }
      
    case confirmField!:
      if let new = newField?.text, textString != new {
        self.saveFooterView.warningLabel.text = "✖︎ " + "New Password and Confirmation does not match"
        return
      }
      
    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("There is no other text fields in this switch-case")
      }
    }
  }
  
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}












