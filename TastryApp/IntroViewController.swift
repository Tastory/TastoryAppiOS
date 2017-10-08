//
//  IntroViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class IntroViewController: TransitableViewController {
  
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
    
    if let currentUser = FoodieUser.current, currentUser.isRegistered {
      guard let username = currentUser.username else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.assert("User doesn't even have a username!")
        }
        return
      }
      
      guard let email = currentUser.email else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.assert("User \(currentUser.username!) doesn't have an E-mail address???")
        }
        return
      }
      
      currentUser.resendEmailVerification { error in
        
        if let error = error as? FoodieUser.ErrorCode {
          switch error {
          case .reverficiationVerified:
            CCLog.info("User \(username) tried to request E-mail verification when \(email) already verified")
            AlertDialog.present(from: self, title: "Resend Error", message: "The E-mail address \(email) have already been verified.") { action in
              self.presentDiscoverVC()
            }
            
          default:
            CCLog.warning("Failed resending E-mail verification to \(email) - \(error.localizedDescription)")
            AlertDialog.present(from: self, title: "Resend Failed", message: error.localizedDescription) { action in
              self.presentDiscoverVC()
            }
          }
        } else if let error = error {
          CCLog.warning("Failed resending E-mail verification to \(email) - \(error.localizedDescription)")
          AlertDialog.present(from: self, title: "Resend Failed", message: error.localizedDescription) { action in
            self.presentDiscoverVC()
          }
        } else {
          CCLog.info("E-mail verificaiton resent to \(email)")
          AlertDialog.present(from: self, title: "Verification Resent!", message: "Please check your E-mail and confirm your address!") { action in
            self.presentDiscoverVC()
          }
        }
      }
    } else {
      AlertDialog.present(from: self, title: "Resend Error", message: "Fatal Internal Inconsistency. Please restart the app and try again") { action in
        CCLog.fatal("E-mail verification request when user is not even logged in!")
      }
    }
  }
  
  
  
  @IBAction func letsGoAction(_ sender: UIButton) {
    presentDiscoverVC()
  }
  
    
    
  // MARK: - Private Instance Function
  private func presentDiscoverVC() {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MapViewController") as? MapViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of MapViewController Class!!")
      }
      return
    }
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: false)
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
}
