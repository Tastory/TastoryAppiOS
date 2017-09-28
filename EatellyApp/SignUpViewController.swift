//
//  SignUpViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-27.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class SignUpViewController: UIViewController {

  
  // MARK: - Public Global Variable
  
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
  
  @IBOutlet weak var confirmPwdField: UITextField!
  
  
  
  // MARK: - IBAction
  
  @IBAction func signUpAction(_ sender: UIButton) {
  }
  
  @IBAction func exitAction(_ sender: UIButton) {
    dismiss(animated: true, completion: nil)
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
