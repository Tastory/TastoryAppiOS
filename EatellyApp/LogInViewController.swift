//
//  LogInViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Eatelly. All rights reserved.
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
    // TODO: - This is obviously temporary just to keep the app somewhat functional. Real Log-in should be implemented here
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController")
    self.present(viewController, animated: true)
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
  }
  
  
  @IBAction func facebookAction(_ sender: UIButton) {
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
}
