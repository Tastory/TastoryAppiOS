//
//  SettingsMenuViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class SettingsMenuViewController: OverlayViewController {
  
  // MARK: - Public Instance Variable
  
  var parentNavController: UINavigationController?
  
  
  // MARK: - IBOutlet
  
  @IBOutlet var linkFacebookLine: UIView!
  @IBOutlet var linkFacebookCell: UIView!
  @IBOutlet var linkFacebookLabel: UILabel!
  @IBOutlet var linkFacebookArrow: UIImageView!
  @IBOutlet var linkFacebookTapRecognizer: UITapGestureRecognizer!
  
  @IBOutlet var changePasswordLine: UIView!
  @IBOutlet var changePasswordCell: UIView!
  
  
  // MARK: - IBAction
  
  @IBAction func profileDetailsTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ProfileDetailViewController") as? ProfileDetailViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of ProfileDetailViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func changePasswordTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "PasswordViewController") as? PasswordViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of PasswordViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func linkFacebookTap(_ sender: UITapGestureRecognizer) {
    guard let currentUser = FoodieUser.current else {
      AlertDialog.present(from: self, title: "Not Logged In", message: "This operation cannot be performed in a non-logged in state") { _ in
        CCLog.warning("Link Facebook attempted with FoodieUser.current = nil")
      }
      return
    }
    
    currentUser.linkFacebook { (error) in
      if let error = error {
        AlertDialog.present(from: self, title: "Facebook Error", message: error.localizedDescription) { _ in
          CCLog.warning("Facebook Link Failed - \(error.localizedDescription)")
        }
        return
      }
      self.updateFacebookCell()
    }
  }
  
  
  @IBAction func librariesTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "LibrariesViewController") as? LibrariesViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of LibrariesViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func privacyPolicyTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "PrivacyPolicyViewController") as? PrivacyPolicyViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of PrivacyPolicyViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func serviceTermsTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ServiceTermsViewController") as? ServiceTermsViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of ServiceTermsViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func aboutUsTap(_ sender: UITapGestureRecognizer) {
    CCLog.warning("About Us Not Yet Implemented")
  }
  
  
  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    parentNavController?.popViewController(animated: true)
  }
  
  
  @objc private func logoutAction(_ sender: UIBarButtonItem) {
    guard let vc = parentNavController else {
      CCLog.fatal("parentNavController == nil")
    }
    LogOutDismiss.askDiscardIfNeeded(from: vc)
  }
  

  private func updateFacebookCell() {
    // Update the Facebook Link Cell
    guard let currentUser = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.warning("FoodieUser.current = nil")
      }
      return
    }
    
    if currentUser.isFacebookLinked {
      currentUser.getFacebookName() { (object, error) in
        if let error = error {
          CCLog.warning("Get Facebook Name failed - \(error.localizedDescription)")
        }
        
        guard let name = object as? String else {
          CCLog.warning("Could not obtain name from Facebook Graph request?")
          return
        }
        
        self.linkFacebookLabel.text = "Facebook Account - \(name)"
        self.linkFacebookArrow.isHidden = true
        self.linkFacebookTapRecognizer.isEnabled = false
      }
    } else {
      linkFacebookLabel.text = "Link Account to Facebook"
      self.linkFacebookArrow.isHidden = false
      linkFacebookTapRecognizer.isEnabled = true
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-LeftArrowDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutAction(_:)))
    
    let titleTextAttributes = [NSAttributedStringKey.font : UIFont(name: "Raleway-Semibold", size: 14)!,
                               NSAttributedStringKey.strokeColor : FoodieGlobal.Constants.TextColor]
    navigationItem.rightBarButtonItem!.setTitleTextAttributes(titleTextAttributes, for: .normal)
    navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
    
    updateFacebookCell()
    
    guard let currentUser = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.warning("FoodieUser.current = nil")
      }
      return
    }
    
    if currentUser.isFacebookOnly {
      self.changePasswordCell.isHidden = true
      self.changePasswordLine.isHidden = true
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
}
