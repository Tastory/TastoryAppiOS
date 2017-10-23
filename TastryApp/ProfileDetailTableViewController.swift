//
//  ProfileDetailTableViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//


import UIKit
import MobileCoreServices


class ProfileDetailTableViewController: UITableViewController {
  
  // MARK: - Constants
  struct Constants {
    static let ProfileBorderColor = FoodieGlobal.Constants.ThemeColor
    static let ProfileBorderWidth: CGFloat = 5.0
    static let ProfileCornerRadius: CGFloat = 15.0
    static let ProfileHeaderHeight: CGFloat = 180.0
    static let EmailFooterHeight: CGFloat = 110.0
    static let EmptyFooterHeight: CGFloat = 30.0
    static let SaveFooterHeight: CGFloat = 70.0
  }
  
  
  
  // MARK: - Private Instance Variable
  private var headerView: ProfileTableHeaderView!
  private var emailFooterView: ProfileTableEmailFooterView!
  private var saveFooterView: ProfileTableSaveFooterView!
  
  
  
  // MARK: - Public Instance Variable
  var user: FoodieUser!

  
  
  // MARK: - Private Instance Functions
  @objc private func changeProfileImage() {
    let imagePickerController = UIImagePickerController()
    imagePickerController.sourceType = .photoLibrary
    imagePickerController.allowsEditing = true
    imagePickerController.delegate = self
    imagePickerController.mediaTypes = [kUTTypeImage as String]
    
    self.present(imagePickerController, animated: true, completion: nil)
  }
  
  
  @objc private func resendEmailConfirmation() {
    guard let email = user.email else {
      AlertDialog.present(from: self, title: "No E-mail Address", message: "No E-mail Address, please fill in the E-mail and try again") { action in
        CCLog.warning("No E-mail address when user tried to reconfirm E-mail address")
      }
      return
    }
    
    user.resendEmailVerification { error in
      if let error = error {
        AlertDialog.present(from: self, title: "E-mail Re-confirmation Failed", message: "Error - \(error.localizedDescription). Please try again") { action in
          CCLog.warning("E-mail Re-confirmation Failed. Error - \(error.localizedDescription)")
        }
        return
      } else {
        AlertDialog.present(from: self, title: "E-mail Sent!", message: "An E-mail confirmation have been sent to \(email)")
      }
    }
  }
  
  
  @objc private func saveUser() {
    user.saveRecursive(to: .both, type: .cache) { error in
      if let error = error {
        AlertDialog.present(from: self, title: "Save User Details Failed", message: "Error - \(error.localizedDescription). Please try again") { action in
          CCLog.warning("user.saveRecursive Failed. Error - \(error.localizedDescription)")
        }
        return
      }
      
      self.user.oldMedia?.deleteRecursive(from: .both, type: .cache, withBlock: nil)
      AlertDialog.present(from: self, title: "User Details Updated!", message: "")
    }
  }
  
  
  private func updateAllUIDisplayed() {
    DispatchQueue.main.async {
      // Update the UI according to the current User object
      if !self.user.isEmailVerified {
        self.emailFooterView.emailButton.isHidden = false
        self.emailFooterView.emailLabel.isHidden = false
        self.emailFooterView.emailFooterHeight = Constants.EmailFooterHeight
      } else {
        self.emailFooterView.emailButton.isHidden = true
        self.emailFooterView.emailLabel.isHidden = true
        self.emailFooterView.emailFooterHeight = Constants.EmptyFooterHeight
      }
      
      if self.user.isDirty {
        self.saveFooterView.saveButton.setTitleColor(UIColor.blue, for: .normal)
        self.saveFooterView.saveButton.isEnabled = true
      } else {
        self.saveFooterView.saveButton.setTitleColor(UIColor.gray, for: .normal)
        self.saveFooterView.saveButton.isEnabled = false
      }
      
      // Extract the profile image from the User object
      if let profileImageBuffer = self.user.media?.imageMemoryBuffer, let profileImage = UIImage(data: profileImageBuffer) {
        self.headerView.profileImageButton.setImage(profileImage, for: .normal)
        self.headerView.profileImageButton.imageView?.contentMode = .scaleAspectFill
      } else {
        CCLog.warning("No associated Profile Image Filename")
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let headerNib = UINib(nibName: "ProfileTableHeaderView", bundle: nil)
    guard let headerView = headerNib.instantiate(withOwner: self, options: nil)[0] as? ProfileTableHeaderView else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Cannot create ProfileTableHeaderView from Nib")
      }
      return
    }
    self.headerView = headerView
    
    let emailFooterNib = UINib(nibName: "ProfileTableEmailFooterView", bundle: nil)
    guard let emailFooterView = emailFooterNib.instantiate(withOwner: self, options: nil)[0] as? ProfileTableEmailFooterView else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Cannot create ProfileTableEmailFooterView from Nib")
      }
      return
    }
    self.emailFooterView = emailFooterView
    
    let saveFooterNib = UINib(nibName: "ProfileTableSaveFooterView", bundle: nil)
    guard let saveFooterView = saveFooterNib.instantiate(withOwner: self, options: nil)[0] as? ProfileTableSaveFooterView else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Cannot create ProfileTableSaveFooterView from Nib")
      }
      return
    }
    self.saveFooterView = saveFooterView
    
    // These are UI properties that does not change
    self.headerView.profileImageButton.borderColor = Constants.ProfileBorderColor
    self.headerView.profileImageButton.borderWidth = Constants.ProfileBorderWidth
    self.headerView.profileImageButton.cornerRadius = Constants.ProfileCornerRadius
    self.headerView.profileImageButton.addTarget(self, action: #selector(changeProfileImage), for: .touchUpInside)
    self.headerView.headerHeight = Constants.ProfileHeaderHeight
    
    self.emailFooterView.emailButton.setTitle("Re-send Confirmation", for: .normal)
    self.emailFooterView.emailButton.addTarget(self, action: #selector(resendEmailConfirmation), for: .touchUpInside)
    self.emailFooterView.emailLabel.text = "We've sent an E-mail to your inbox to confirm you new E-mail address. Use the button above if you haven't received it yet."
    
    self.saveFooterView.saveButton.setTitle("Save Changes", for: .normal)
    self.saveFooterView.saveButton.addTarget(self, action: #selector(saveUser), for: .touchUpInside)
    self.saveFooterView.saveFooterHeight = Constants.SaveFooterHeight
    
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("We are only supporting User Detail View for Current User only")
    }
    user = currentUser

    user.retrieveRecursive(from: .both, type: .cache, forceAnyways: false, withReady: nil) { error in
      
      if let error = error {
        AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain) { action in
          CCLog.warning("Retreive User Recursive Failed with Error - \(error.localizedDescription)")
        }
        return
      }
      
      // See if there's media associated with the user. If so track it as the one to delete if user saves, or the one to restore to if the user discard changes
      self.user.oldMedia = self.user.media
      self.updateAllUIDisplayed()
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  
  // MARK: - Table view data source
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if section == 0 {
      return headerView
    } else {
      return nil
    }
  }
  
  override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    if section == 0 {
      return emailFooterView
    } else if section == 1 {
      return saveFooterView
    } else {
      return nil
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return headerView.headerHeight
    } else {
      return 0
    }
  }
  
  override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return headerView.headerHeight
    } else {
      return 0
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    if section == 0 {
      return emailFooterView.emailFooterHeight
    } else if section == 1 {
      return saveFooterView.saveFooterHeight
    } else {
      return Constants.EmptyFooterHeight
    }
  }
  
  override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
    if section == 0 {
      return emailFooterView.emailFooterHeight
    } else if section == 1 {
      return saveFooterView.saveFooterHeight
    } else {
      return Constants.EmptyFooterHeight
    }
  }
}


extension ProfileDetailTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
    
    guard let mediaType = info[UIImagePickerControllerMediaType] as? String else {
      CCLog.assert("Media type is expected after selection from image picker")
      return
    }
    
    picker.dismiss(animated:true, completion: nil)
    
    var mediaObject: FoodieMedia
    var mediaName: String
    
    switch mediaType {
      
    case String(kUTTypeMovie):
      
      CCLog.assert("Movie type for Profile not yet supported")
      return
      
//      guard let movieUrl = info[UIImagePickerControllerMediaURL] as? NSURL else {
//        CCLog.assert("video URL is not returned from image picker")
//        return
//      }
//
//      guard let movieName = movieUrl.lastPathComponent else {
//        CCLog.assert("video URL is missing movie name")
//        return
//      }
//
//      guard let moviePath = movieUrl.relativePath else {
//        CCLog.assert("video URL is missing relative path")
//        return
//      }
//
//      mediaObject = FoodieMedia(for: movieName, localType: .draft, mediaType: .video)
//      let avExportPlayer = AVExportPlayer()
//      avExportPlayer.initAVPlayer(from: URL(fileURLWithPath: moviePath))
//      mediaObject.videoExportPlayer = avExportPlayer
      
    case String(kUTTypeImage):
      mediaName = FoodieFileObject.newPhotoFileName()
      
      var image: UIImage!
      if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
        image = editedImage
      }
      else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
        image = originalImage
      }
      else {
        CCLog.assert("UIImage is not returned from image picker")
        return
      }
      
      mediaObject = FoodieMedia(for: mediaName, localType: .draft, mediaType: .photo)
      mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(image, CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
      
    default:
      AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { action in
        CCLog.assert("Media returned from Image Picker is neither a Photo nor a Video")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    
    user.changeProfileMedia(to: mediaObject)
    self.updateAllUIDisplayed()
  }
}
