//
//  IntroViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class IntroViewController: UIViewController {
  
  // MARK: - Public Instance Function
  var firstLabelText: String?
  var secondLabelText: String?
  var enableResend: Bool = false

  
  // MARK: - IBOutlet
  @IBOutlet weak var firstLabel: UILabel! {
    didSet {
      if let firstLabelText = firstLabelText {
        firstLabel.text = firstLabelText
      }
    }
  }
  
  
  @IBOutlet weak var secondLabel: UILabel! {
    didSet {
      if let secondLabelText = secondLabelText {
        secondLabel.text = secondLabelText
      }
    }
  }
  
  
  @IBOutlet weak var resendButton: UIButton!
  @IBOutlet weak var resendButtonHeight: NSLayoutConstraint!
  @IBOutlet weak var resendSpacingHeight: NSLayoutConstraint!
  @IBOutlet weak var goSpacingHeight: NSLayoutConstraint!
  
  
  // MARK: - IBAction
  @IBAction func resendAction(_ sender: UIButton) {
    
    if let currentUser = FoodieUser.getCurrent(), currentUser.objectId != nil {
      currentUser.resendEmailVerification { error in
        
        if let error = error {
          CCLog.warning("Failed resending E-mail verification - \(error.localizedDescription)")
          AlertDialog.present(from: self, title: "Resend Failed", message: error.localizedDescription) { action in
            self.presentDiscoverVC()
          }
          return
          
        } else {
          CCLog.debug("E-mail verificaiton resent to \(currentUser.email!)")
          AlertDialog.present(from: self, title: "Verification Resent!", message: "Please check your E-mail and confirm your address!") { action in
            self.presentDiscoverVC()
          }
        }
      }
    }
  }
  
  
  @IBAction func letsGoAction(_ sender: UIButton) {
    presentDiscoverVC()
  }
  
    
    
  // MARK: - Private Instance Function
  private func presentDiscoverVC() {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController")
    self.present(viewController, animated: true)
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if enableResend {
      resendButton.isHidden = false
      resendSpacingHeight.constant = 15
      resendButtonHeight.constant = 20
      goSpacingHeight.constant = 0
    } else {
      resendButton.isHidden = true
      resendSpacingHeight.constant = 0
      resendButtonHeight.constant = 0
      goSpacingHeight.constant = 0
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()

    CCLog.warning("didReceiveMemoryWarning")
  }
}
