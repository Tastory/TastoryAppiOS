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
    static let ProfileHeaderHeight: CGFloat = 190.0
    static let EmailFooterHeight: CGFloat = 130.0
    static let EmptyFooterHeight: CGFloat = 50.0
    static let SaveFooterHeight: CGFloat = 80.0
  }
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var usernameField: UITextField? {
    didSet {
      usernameField?.text = username
      usernameField?.delegate = self
    }
  }
  
  @IBOutlet weak var emailField: UITextField? {
    didSet {
      emailField?.text = email
      emailField?.delegate = self
    }
  }
  
  @IBOutlet weak var fullNameField: UITextField? {
    didSet {
      fullNameField?.text = fullName
      fullNameField?.delegate = self
    }
  }
  
  @IBOutlet weak var websiteField: UITextField? {
    didSet {
      websiteField?.text = websiteString
      websiteField?.delegate = self
    }
  }
  
  @IBOutlet weak var biographyField: UITextViewWithPlaceholder? {
    didSet {
      biographyField?.text = biography
      biographyField?.delegate = self
    }
  }
  
  
  
  // MARK: - Private Instance Variable
  private var activitySpinner: ActivitySpinner!
  private var headerView: ProfileTableHeaderView!
  private var emailFooterView: ProfileTableEmailFooterView!
  private var saveFooterView: ProfileTableSaveFooterView!
  private var profileImageChanged = false
  private var unsavedChanges: Bool = true {
    didSet {
      if unsavedChanges {
        self.saveFooterView.saveButton.setTitleColor(self.view.tintColor, for: .normal)
        self.saveFooterView.saveButton.isEnabled = true
      } else {
        self.saveFooterView.saveButton.setTitleColor(UIColor.gray, for: .normal)
        self.saveFooterView.saveButton.isEnabled = false
      }
    }
  }
  
  private var profileImage: UIImage? { didSet { unsavedChanges = true; profileImageChanged = true } }
  private var username: String? { didSet { if username != oldValue { unsavedChanges = true } } }
  private var email: String? { didSet { if email != oldValue { unsavedChanges = true } } }
  private var fullName: String? { didSet { if fullName != oldValue { unsavedChanges = true } } }
  private var websiteString: String? { didSet { if websiteString != oldValue { unsavedChanges = true } } }
  private var biography: String? { didSet { if biography != oldValue { unsavedChanges = true } } }
  
  
  
  // MARK: - Public Instance Variable
  var user: FoodieUser!

  
  
  // MARK: - IBAction
  
  @IBAction func usernameEdited(_ sender: UITextField) {
    username = sender.text
  }
  
  @IBAction func emailEdited(_ sender: UITextField) {
    email = sender.text
  }
  
  @IBAction func fullnameEdited(_ sender: UITextField) {
    fullName = sender.text
  }
  
  @IBAction func websiteEdited(_ sender: UITextField) {
    websiteString = sender.text
  }
  
  
  
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
    
    guard var username = username else {
      CCLog.warning("username = nil")
      return
    }
    
    guard var email = email else {
      CCLog.warning("email = nil")
      return
    }
    
    // Okay, lower case username and E-mail only.
    username = username.lowercased()
    usernameField?.text = username
    email = email.lowercased()
    emailField?.text = email
    
    // Check for validity and availability before allowing to save
    if let error = FoodieUser.checkValidFor(username: username) {
      AlertDialog.present(from: self, title: "Invalid Username", message: "\(error.localizedDescription)")
      CCLog.info("User entered invalid username - \(error.localizedDescription)")
      return
    }
    
    if !FoodieUser.checkValidFor(email: email) {
      AlertDialog.present(from: self, title: "Invalid E-mail", message: "Address entered is not of valid E-mail address format")
      CCLog.info("Address \(email) entered is not of valid E-mail address format")
      return
    }
    
    FoodieUser.checkUserAvailFor(username: username) { (usernameSuccess, usernameError) in
      FoodieUser.checkUserAvailFor(email: email) { (emailSuccess, emailError) in
        
        // Transfer all buffer data into the user
        if username != self.user.username! {
          
          // Look at result of Username check only if Username changed
          if let usernameError = usernameError {
            AlertDialog.present(from: self, title: "Save Failed", message: "Unable to check Username Validity")
            CCLog.warning("checkUserAvailFor username: (\(username)) Failed - \(usernameError.localizedDescription)")
            return
          } else if !usernameSuccess {
            AlertDialog.present(from: self, title: "Username Unavailable", message: "Username \(username) already taken")
            CCLog.info("checkUserAvailFor username: (\(username)) already exists")
            return
          }
          self.user.username = username
        }
      
        if email != self.user.email! {
          
          // Look at result of E-mail check only if E-mail changed
          if let emailError = emailError {
            AlertDialog.present(from: self, title: "Save Failed", message: "Unable to check E-mail Validity")
            CCLog.warning("checkUserAvailFor E-mail: (\(email)) Failed - \(emailError.localizedDescription)")
            return
          } else if !emailSuccess {
            AlertDialog.present(from: self, title: "E-mail Unavailable", message: "E-mail Address \(email) already taken")
            CCLog.info("checkUserAvailFor E-mail: (\(email)) already exists")
            return
          }
          self.user.email = email
          self.user.forceEmailUnverified()
        }
        
        self.user.fullName = self.fullName
        self.user.url = self.websiteString
        self.user.biography = self.biography
        
        var oldMedia: FoodieMedia?
        if self.profileImageChanged, let profileImage = self.profileImage {
          oldMedia = self.user.media
          let mediaObject = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
          mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(profileImage, CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
          self.user.changeProfileMedia(to: mediaObject)
        }
        
        self.user.saveRecursive(to: .both, type: .cache) { error in
          if let error = error {
            AlertDialog.present(from: self, title: "Save User Details Failed", message: "Error - \(error.localizedDescription). Please try again") { action in
              CCLog.warning("user.saveRecursive Failed. Error - \(error.localizedDescription)")
            }
            return
          }
          
          oldMedia?.deleteRecursive(from: .both, type: .cache, withBlock: nil)
          self.unsavedChanges = false
          self.profileImageChanged = false
          
          self.updateAllUIDisplayed()
          AlertDialog.present(from: self, title: "User Details Updated!", message: "")
        }
      }
    }
  }
  
  
  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }
  
  
  @objc private func keyboardWillHide(notification: Notification) {
    if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      let viewHeight = self.view.frame.height
      self.view.frame = CGRect(x: self.view.frame.origin.x,
                               y: self.view.frame.origin.y,
                               width: self.view.frame.width,
                               height: viewHeight + keyboardSize.height)
    } else {
      CCLog.assert("We're about to hide the keyboard and the keyboard size is nil. Now is the rapture.")
    }
  }
  
  
  @objc private func keyboardWillShow(notification: Notification) {
    if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      // We're not just minusing the kb height from the view height because
      // the view could already have been resized for the keyboard before
      self.view.frame = CGRect(x: self.view.frame.origin.x,
                               y: self.view.frame.origin.y,
                               width: self.view.frame.width,
                               height: UIScreen.main.bounds.height - keyboardSize.height)
    } else {
      CCLog.assert("We're showing the keyboard and either the keyboard size or window is nil: panic widely.")
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
      
      if self.unsavedChanges {
        self.saveFooterView.saveButton.setTitleColor(self.view.tintColor, for: .normal)
        self.saveFooterView.saveButton.isEnabled = true
      } else {
        self.saveFooterView.saveButton.setTitleColor(UIColor.gray, for: .normal)
        self.saveFooterView.saveButton.isEnabled = false
      }
      
      // Extract the profile image from the User object
      if let profileImage = self.profileImage {
        self.headerView.profileImageButton.setImage(profileImage, for: .normal)
      }
      self.headerView.profileImageButton.imageView?.contentMode = .scaleAspectFill
      self.tableView.reloadData()
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
    
    // Apply some default UI properties
    self.emailFooterView.emailButton.isHidden = true
    self.emailFooterView.emailLabel.isHidden = true
    self.emailFooterView.warningLabel.text = ""
    self.emailFooterView.emailFooterHeight = Constants.EmptyFooterHeight
    self.saveFooterView.saveButton.setTitleColor(UIColor.gray, for: .normal)
    self.saveFooterView.saveButton.isEnabled = false
    self.headerView.profileImageButton.setImage(#imageLiteral(resourceName: "AddProfileIcon"), for: .normal)
    
    // Add a Tap gesture recognizer to dismiss th keyboard when needed
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGestureRecognizer.numberOfTapsRequired = 1
    tapGestureRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(tapGestureRecognizer)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: Notification.Name.UIKeyboardWillHide, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: Notification.Name.UIKeyboardWillShow, object: nil)

    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("We are only supporting User Detail View for Current User only")
    }
    user = currentUser
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    self.user.retrieveRecursive(from: .both, type: .cache, forceAnyways: true, withReady: nil) { error in
      if let error = error {
        AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain) { action in
          CCLog.warning("Retreive User Recursive Failed with Error - \(error.localizedDescription)")
        }
        return
      }
      
      // Put all user data into temporary view buffers
      
      DispatchQueue.main.async {
        // Extract the profile image from the User object
        if let profileImageBuffer = self.user.media?.imageMemoryBuffer, let profileImage = UIImage(data: profileImageBuffer) {
          self.profileImage = profileImage
        } else {
          CCLog.warning("No associated Profile Image Filename")
        }
        
        if let username = self.user.username {
          self.username = username
          self.usernameField?.text = username
        } else {
          CCLog.assert("User has no username??")
        }
        
        if let email = self.user.email {
          self.email = email
          self.emailField?.text = email
        } else {
          CCLog.assert("User has no E-mail??")
        }
        
        if let fullName = self.user.fullName {
          self.fullName = fullName
          self.fullNameField?.text = fullName
        }
        
        if let url = self.user.url {
          self.websiteString = url
          self.websiteField?.text = url
        }
        
        if let biography = self.user.biography {
          self.biography = biography
          self.biographyField?.text = biography
        }
        
        // Reset unsaved changes
        self.unsavedChanges = false
        self.profileImageChanged = false
        self.updateAllUIDisplayed()
      }
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  deinit {
    //NotificationCenter.default.removeObserver(self)
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


extension ProfileDetailTableViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    biography = textView.text
  }
}


extension ProfileDetailTableViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    
    switch textField {
    case usernameField!:
      self.emailFooterView.warningLabel.text = ""
      guard var textString = textField.text, textString.characters.count >= FoodieUser.Constants.MinUsernameLength, let username = user.username, textString != username else {
        return  // No text, nothing to see here
      }
      
      // Okay. Lower cased usernames only
      textString = textString.lowercased()
      textField.text = textString
      
      if let error = FoodieUser.checkValidFor(username: textString) {
        emailFooterView.warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
      
      FoodieUser.checkUserAvailFor(username: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor username: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.emailFooterView.warningLabel.text = "✖︎ " + "Username '\(textString)' is not available"
          }
        }
      }
      
    case emailField!:
      emailFooterView.warningLabel.text = ""
      guard var textString = textField.text, textString.characters.count >= FoodieUser.Constants.MinEmailLength, let email = user.email, textString != email else {
        return  // No yet an E-mail, nothing to see here
      }
      
      // Lower cased emails only too
      textString = textString.lowercased()
      textField.text = textString
      
      if !FoodieUser.checkValidFor(email: textString) {
        self.emailFooterView.warningLabel.text = "Address entered is not of valid E-mail address format"
        return
      }
      
      FoodieUser.checkUserAvailFor(email: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor E-mail: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.emailFooterView.warningLabel.text = "✖︎ " + "E-mail address \(textString) is already signed up"
          }
        }
      }
    
    default:
      // Just ignore the other fields. They don't need to check for invalid
      break
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
    
    switch mediaType {
      
    case String(kUTTypeMovie):
      CCLog.assert("Movie type for Profile not yet supported")
      return
      
    case String(kUTTypeImage):
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
      self.profileImage = image
      
    default:
      AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { action in
        CCLog.assert("Media returned from Image Picker is neither a Photo nor a Video")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    
    self.updateAllUIDisplayed()
  }
}
