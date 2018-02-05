//
//  SettingsMenuViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit
import Photos
import SafariServices

class SettingsMenuViewController: OverlayViewController {
  
  
  // MARK: - Constants
  
  struct Constants {
    static let DefaultLinkToFacebookCellText = "Link Account to Facebook"
    static let AboutUsUrl = "https://www.tastory.co/connect/"
  }
  
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
  
  @IBOutlet var saveMediaSwitch: UISwitch!
  
  @IBOutlet var versionBuildLabel: UILabel!
  
  
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
    
    facebookCell(isEnabled: false, with: "Linking to Facebook...")
    
    currentUser.linkFacebook { [weak self] error in
      if let error = error {
        self?.facebookCell(isEnabled: true, with: Constants.DefaultLinkToFacebookCellText)
        
        // Do not show Alert Dialog for Error related to Cancel. This is the iOS 11 case
        if #available(iOS 11.0, *),
          let sfError = error as? SFAuthenticationError,
          sfError.errorCode == SFAuthenticationError.Code.canceledLogin.rawValue {
          
          CCLog.info("Facebook link cancelled")
          return
        }
        
        // Do not show Alert Dialog for Error related to Cancel. This is the iOS 10 case
        if let foodieError = error as? FoodieUser.ErrorCode {
          switch foodieError {
          case .facebookCurrentAccessTokenNil:
            CCLog.info("Facebook link cancelled")
            return
            
          default:
            break
          }
        }
        
        // So Facebook link failed for some odd reason. Best effort unlink if necassary
        currentUser.unlinkFacebook(withBlock: nil)
        
        if let unwrappedSelf = self {
          DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.6) {
            AlertDialog.present(from: unwrappedSelf, title: "Facebook Error", message: error.localizedDescription) { _ in
              CCLog.warning("Facebook Link Failed - \(error.localizedDescription)")
            }
          }
        }
        return
      }
      
      self?.updateFacebookCell()
    }
  }

  
  @IBAction func saveMediaToggled(_ sender: UISwitch) {
    guard let currentUser = FoodieUser.current else {
      AlertDialog.present(from: self, title: "Not Logged In", message: "This operation cannot be performed in a non-logged in state") { _ in
        CCLog.warning("Link Facebook attempted with FoodieUser.current = nil")
      }
      return
    }
    
    // Only need to make sure we have permission if we are being turned on
    if sender.isOn {
      switch PHPhotoLibrary.authorizationStatus() {
      case .authorized:
        break
        
      case .restricted:
        self.saveMediaSwitch.setOn(false, animated: true)
        AlertDialog.present(from: self, title: "Photos Restricted", message: "Photo access have been restricted by the operating system. Save media to library is not possible") { _ in
          CCLog.warning("Photo Library Authorization Restricted")
        }
        
      case .denied:
        self.saveMediaSwitch.setOn(false, animated: true)
        let appName = Bundle.main.displayName ?? "Tastory"
        let urlDialog = AlertDialog.createUrlDialog(title: "Photo Library Inaccessible",
                                                    message: "Please go to Settings > Privacy > Photos to allow \(appName) to access your Photo Library, then try again",
                                                    url: UIApplicationOpenSettingsURLString)
        
        self.present(urlDialog, animated: true, completion: nil)
        
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization { status in
          switch status {
          case .authorized:
            break

          case .restricted:
            AlertDialog.present(from: self, title: "Photos Restricted", message: "Photo access have been restricted by the operating system. Save media to library is not possible") { _ in
              CCLog.warning("Photo Library Authorization Restricted")
            }
            fallthrough
            
          default:
            DispatchQueue.main.async {
              self.saveMediaSwitch.setOn(false, animated: true)
              currentUser.saveOriginalsToLibrary = false
              currentUser.saveDigest(to: .both, type: .cache) { error in
                if let error = error {
                  CCLog.warning("User save for Media Toggle failed - \(error.localizedDescription)")
                }
              }
            }
          }
        }
      }
    }
    
    if currentUser.saveOriginalsToLibrary != self.saveMediaSwitch.isOn {  // Not using sender, because it might get outdated?
      currentUser.saveOriginalsToLibrary = self.saveMediaSwitch.isOn
      currentUser.saveDigest(to: .both, type: .cache) { error in
        if let error = error {
          CCLog.warning("User save for Media Toggle failed - \(error.localizedDescription)")
        }
      }
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
    if let websiteUrl = URL(string: Constants.AboutUsUrl) {
      CCLog.info("Opening Safari View for \(websiteUrl)")
      let safariViewController = SFSafariViewController(url: websiteUrl)
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
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
  
  
  private func facebookCell(isEnabled enabled: Bool, with text: String) {
    linkFacebookLabel.text = text
    linkFacebookArrow.isHidden = !enabled
    linkFacebookTapRecognizer.isEnabled = enabled
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
      facebookCell(isEnabled: false, with: "Linked to Facebook Account")
      
      currentUser.getFacebookName() { [weak self] (object, error) in
        if let error = error {
          CCLog.warning("Get Facebook Name failed - \(error.localizedDescription)")
          return
        }
        
        guard let name = object as? String else {
          CCLog.warning("Could not obtain name from Facebook Graph request?")
          return
        }
        
        self?.facebookCell(isEnabled: false, with: "Facebook Account - \(name)")
      }
    } else {
      facebookCell(isEnabled: true, with: "Link Account to Facebook")
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-LeftArrowDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutAction(_:)))
    navigationItem.rightBarButtonItem?.accessibilityIdentifier = "profileView_logoutButton"
    
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
    
    saveMediaSwitch.setOn(currentUser.saveOriginalsToLibrary, animated: false)
    saveMediaToggled(saveMediaSwitch)
    
    let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    var buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    
    // Append leading 0 to build number if needed
    while buildNumber.count < 3 {
      buildNumber = "0" + buildNumber
    }
    
    versionBuildLabel.text = "Tastory Ver \(appVersionString) B\(buildNumber)"
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
}
