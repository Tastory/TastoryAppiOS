//
//  SignUpViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class SignUpViewController: UIViewController {
  
  
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
  }
  
  
  
  @IBAction func hideShowPwdAction(_ sender: UIButton) {
  }
  
  
  
  
  @IBAction func exitAction(_ sender: UIButton) {
    dismiss(animated: true, completion: nil)
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    usernameField.becomeFirstResponder()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}



// MARK: - Protocol Conformance for UITextFieldDelegate

extension SignUpViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    //code
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    //code
    return true
  }
}
