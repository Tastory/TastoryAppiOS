//
//  IntroViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit

class IntroViewController: OverlayViewController {
  
  // MARK: - Public Instance Function
  var firstLabelText: String?
  var secondLabelText: String?
  var enableResend: Bool = false

  @IBOutlet weak var letsGoButton: UIButton!

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
  
  
  
  // MARK: - IBAction
  @IBAction func resendAction(_ sender: UIButton) {
    
    if let currentUser = FoodieUser.current, currentUser.isRegistered {
      guard let username = currentUser.username else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.assert("User doesn't even have a username!")
        }
        return
      }
      
      guard let email = currentUser.email else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.assert("User \(currentUser.username!) doesn't have an E-mail address???")
        }
        return
      }
      
      currentUser.resendEmailVerification { error in
        
        if let error = error as? FoodieUser.ErrorCode {
          switch error {
          case .reverficiationVerified:
            CCLog.info("User \(username) tried to request E-mail verification when \(email) already verified")
            AlertDialog.present(from: self, title: "Resend Error", message: "The E-mail address \(email) have already been verified.") { [unowned self] _ in
              self.presentDiscoverVC()
            }
            
          default:
            CCLog.warning("Failed resending E-mail verification to \(email) - \(error.localizedDescription)")
            AlertDialog.present(from: self, title: "Resend Failed", message: error.localizedDescription) { [unowned self] _ in
              self.presentDiscoverVC()
            }
          }
        } else if let error = error {
          CCLog.warning("Failed resending E-mail verification to \(email) - \(error.localizedDescription)")
          AlertDialog.present(from: self, title: "Resend Failed", message: error.localizedDescription) { [unowned self] _ in
            self.presentDiscoverVC()
          }
        } else {
          CCLog.info("E-mail verificaiton resent to \(email)")
          AlertDialog.present(from: self, title: "Verification Resent!", message: "Please check your E-mail and confirm your address!") { [unowned self] _ in
            self.presentDiscoverVC()
          }
        }
      }
    } else {
      AlertDialog.present(from: self, title: "Resend Error", message: "Fatal Internal Inconsistency. Please restart the app and try again") { _ in
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
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if enableResend {
      resendButton.isHidden = false
    } else {
      resendButton.isHidden = true
    }
  }
}
