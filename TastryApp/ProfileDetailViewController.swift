//
//  ProfileDetailViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import SafariServices
import MobileCoreServices


class ProfileDetailViewController: OverlayViewController {
  
  
  // MARK: - Private Instance Variable
  
  private var activitySpinner: ActivitySpinner!
  private var isInitialLayout = true
  private var profileImageChanged = false
  private var unsavedChanges: Bool = true {
    didSet {
      if unsavedChanges {
        navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
        navigationItem.rightBarButtonItem!.isEnabled = true
      } else {
        navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.TextColor
        navigationItem.rightBarButtonItem!.isEnabled = false
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
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var avatarFrameView: UIImageView!
  @IBOutlet weak var avatarImageView: UIImageView!
  @IBOutlet weak var warningLabel: UILabel!
  @IBOutlet weak var emailButton: UIButton!
  @IBOutlet weak var emailLabel: UILabel!
  @IBOutlet weak var websiteButton: UIButton!
  
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
  
  @IBAction func websitePreview(_ sender: UIButton) {
    CCLog.info("User tapped Website Preview")
    
    if let linkText = websiteField?.text, let url = URL(string: URL.addHttpIfNeeded(to: linkText)) {
      websiteString = linkText
      
      CCLog.info("Opening Safari View for \(url)")
      let safariViewController = SFSafariViewController(url: url)
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  @IBAction func emailAction(_ sender: UIButton) {
    guard let email = user.email else {
      AlertDialog.present(from: self, title: "No E-mail Address", message: "No E-mail Address, please fill in the E-mail and try again") { _ in
        CCLog.warning("No E-mail address when user tried to reconfirm E-mail address")
      }
      return
    }
    
    user.resendEmailVerification { error in
      if let error = error {
        AlertDialog.present(from: self, title: "E-mail Re-confirmation Failed", message: "Error - \(error.localizedDescription). Please try again") { _ in
          CCLog.warning("E-mail Re-confirmation Failed. Error - \(error.localizedDescription)")
        }
        return
      } else {
        AlertDialog.present(from: self, title: "E-mail Sent!", message: "An E-mail confirmation have been sent to \(email)")
      }
    }
  }
  
  
  @IBAction func avatarTapped(_ sender: UITapGestureRecognizer) {
    let imagePickerController = UIImagePickerController()
    imagePickerController.sourceType = .photoLibrary
    imagePickerController.allowsEditing = true
    imagePickerController.delegate = self
    imagePickerController.mediaTypes = [kUTTypeImage as String]
    
    self.present(imagePickerController, animated: true, completion: nil)
  }
  
  
  
  // MARK: - Private Instance Functions
  
  @objc private func saveUser() {
    
    // Get a last minute update of the fields
    username = usernameField?.text
    email = emailField?.text
    fullName = fullNameField?.text
    websiteString = websiteField?.text
    biography = biographyField?.text
    
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
    
    // See if there's a web address. If so check for validity and changed if needed
    if let urlString = websiteString?.trimmingCharacters(in: .whitespacesAndNewlines), urlString != "" {
      if URL(string: URL.addHttpIfNeeded(to: urlString)) != nil {
        websiteField?.text = urlString
      } else {
        AlertDialog.present(from: self, title: "Invalid Web Address", message: "Please enter a valid Web Address URL")
        CCLog.info("User entered invalid web address URL - \(urlString)")
        return
      }
    }
    
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
    
    activitySpinner.apply()
    
    FoodieUser.checkUserAvailFor(username: username) { (usernameSuccess, usernameError) in
      FoodieUser.checkUserAvailFor(email: email) { (emailSuccess, emailError) in
        
        // Transfer all buffer data into the user
        if username != self.user.username! {
          
          // Look at result of Username check only if Username changed
          if let usernameError = usernameError {
            AlertDialog.present(from: self, title: "Save Failed", message: "Unable to check Username Validity")
            CCLog.warning("checkUserAvailFor username: (\(username)) Failed - \(usernameError.localizedDescription)")
            self.activitySpinner.remove()
            return
          } else if !usernameSuccess {
            AlertDialog.present(from: self, title: "Username Unavailable", message: "Username \(username) already taken")
            CCLog.info("checkUserAvailFor username: (\(username)) already exists")
            self.activitySpinner.remove()
            return
          }
          self.user.username = username
        }
        
        if email != self.user.email! {
          
          // Look at result of E-mail check only if E-mail changed
          if let emailError = emailError {
            AlertDialog.present(from: self, title: "Save Failed", message: "Unable to check E-mail Validity")
            CCLog.warning("checkUserAvailFor E-mail: (\(email)) Failed - \(emailError.localizedDescription)")
            self.activitySpinner.remove()
            return
          } else if !emailSuccess {
            AlertDialog.present(from: self, title: "E-mail Unavailable", message: "E-mail Address \(email) already taken")
            CCLog.info("checkUserAvailFor E-mail: (\(email)) already exists")
            self.activitySpinner.remove()
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
          self.user.media = mediaObject
        }
        
        _ = self.user.saveWhole(to: .both, type: .cache) { error in
          self.activitySpinner.remove()
          if let error = error {
            AlertDialog.present(from: self, title: "Save User Details Failed", message: "Error - \(error.localizedDescription). Please try again") { _ in
              CCLog.warning("user.saveWhole Failed. Error - \(error.localizedDescription)")
            }
            return
          }
          
          _ = oldMedia?.deleteRecursive(from: .both, type: .cache, withBlock: nil)
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
  
  
  @objc private func keyboardWillShow(_ notification: NSNotification) {
    if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      // 20 as arbitrary value so there's some space between the text field in focus and the top of the keyboard
      scrollView.contentInset.bottom = keyboardSize.height + 20
    }
  }
  
  @objc private func keyboardWillHide(_ notification: NSNotification) {
    scrollView.contentInset.bottom = 0
  }
  

  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    popDismiss(animated: true)
  }
  
  
  private func updateAllUIDisplayed() {
    DispatchQueue.main.async {
      // Update the UI according to the current User object
      if !self.user.isEmailVerified {
        self.emailButton.isHidden = false
        self.emailLabel.isHidden = false
        self.view.layoutIfNeeded()
      } else {
        self.emailButton.isHidden = true
        self.emailLabel.isHidden = true
        self.view.layoutIfNeeded()
      }
      
      if self.unsavedChanges {
        self.navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
        self.navigationItem.rightBarButtonItem!.isEnabled = true
      } else {
        self.navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.TextColor
        self.navigationItem.rightBarButtonItem!.isEnabled = false
      }
      
      // Extract the profile image from the User object
      if let profileImage = self.profileImage {
        self.avatarImageView.image = profileImage
        self.avatarImageView.contentMode = .scaleAspectFill
      }
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationController?.delegate = self
    
    let leftArrowImage = UIImage(named: "Settings-LeftArrowDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveUser))
    
    let titleTextAttributes = [NSAttributedStringKey.font : UIFont(name: "Raleway-Semibold", size: 14)!,
                               NSAttributedStringKey.strokeColor : FoodieGlobal.Constants.TextColor]
    navigationItem.rightBarButtonItem!.setTitleTextAttributes(titleTextAttributes, for: .normal)
    navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.TextColor  // Text Color by default
    navigationItem.rightBarButtonItem!.isEnabled = false
    
    // Apply some default UI properties
    emailButton.isHidden = true
    emailLabel.isHidden = true
    warningLabel.text = ""
    websiteButton.isHidden = true

    activitySpinner = ActivitySpinner(addTo: view, blurStyle: .dark)
    
    // Add a Tap gesture recognizer to dismiss th keyboard when needed
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGestureRecognizer.numberOfTapsRequired = 1
    tapGestureRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(tapGestureRecognizer)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("We are only supporting User Detail View for Current User only")
    }
    user = currentUser
    
    activitySpinner.apply()
    
    self.user.retrieveWhole(from: .both, type: .cache, forceAnyways: true, withReady: nil) { error in
      
      if let error = error {
        AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain) { _ in
          CCLog.warning("Retreive User Recursive Failed with Error - \(error.localizedDescription)")
        }
        self.activitySpinner.remove()
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
        
        if let url = self.user.url?.trimmingCharacters(in: .whitespacesAndNewlines), url != "" {
          self.websiteString = url
          self.websiteField?.text = url
          self.websiteButton.isHidden = false
        }
        
        if let biography = self.user.biography {
          self.biography = biography
          self.biographyField?.text = biography
        }
        
        // Reset unsaved changes
        self.unsavedChanges = false
        self.profileImageChanged = false
        self.updateAllUIDisplayed()
        self.activitySpinner.remove()
      }
    }
  }
  
  
  override func viewDidLayoutSubviews() {
    if isInitialLayout {
      // Mask the avatar
      guard let maskImage = UIImage(named: "ProfileDetails-BloatedSquareMask") else {
        CCLog.fatal("Cannot get at ProfileDetails-BloatedSquareMask in Resource Bundle")
      }
      
      let maskLayer = CALayer()
      maskLayer.contents = maskImage.cgImage
      maskLayer.frame = avatarImageView.bounds
      avatarImageView.layer.mask = maskLayer
    }
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
  
  
  deinit {
    //NotificationCenter.default.removeObserver(self)
  }
}



extension ProfileDetailViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    biography = textView.text
  }
}



extension ProfileDetailViewController: UITextFieldDelegate {
  func textFieldDidEndEditing(_ textField: UITextField) {
    
    switch textField {
    case usernameField!:
      self.warningLabel.text = ""
      guard var textString = textField.text, textString.count >= FoodieUser.Constants.MinUsernameLength, let username = user.username, textString != username else {
        return  // No text, nothing to see here
      }
      
      // Okay. Lower cased usernames only
      textString = textString.lowercased()
      textField.text = textString
      
      if let error = FoodieUser.checkValidFor(username: textString) {
        warningLabel.text = "✖︎ " + error.localizedDescription
        return
      }
      
      FoodieUser.checkUserAvailFor(username: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor username: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.warningLabel.text = "✖︎ " + "Username '\(textString)' is not available"
          }
        }
      }
      
    case emailField!:
      warningLabel.text = ""
      guard var textString = textField.text, textString.count >= FoodieUser.Constants.MinEmailLength, let email = user.email, textString != email else {
        return  // No yet an E-mail, nothing to see here
      }
      
      // Lower cased emails only too
      textString = textString.lowercased()
      textField.text = textString
      
      if !FoodieUser.checkValidFor(email: textString) {
        self.warningLabel.text = "Address entered is not of valid E-mail address format"
        return
      }
      
      FoodieUser.checkUserAvailFor(email: textString) { (success, error) in
        DispatchQueue.main.async {
          if let error = error {
            CCLog.warning("checkUserAvailFor E-mail: (\(textString)) Failed - \(error.localizedDescription)")
          } else if !success {
            self.warningLabel.text = "✖︎ " + "E-mail address \(textString) is already signed up"
          }
        }
      }
      
    default:
      // Just ignore the other fields. They don't need to check for invalid
      break
    }
  }
  
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let text = textField.text else { return true }
    let newLength = text.utf16.count + string.utf16.count - range.length
    
    if textField === websiteField {
      if newLength > 0 {
        websiteButton.isHidden = false
        self.view.layoutIfNeeded()
      } else {
        websiteButton.isHidden = true
        self.view.layoutIfNeeded()
      }

    }
    return true
  }
  
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}


extension ProfileDetailViewController: UIImagePickerControllerDelegate {
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
      AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { [unowned self] _ in
        CCLog.assert("Media returned from Image Picker is neither a Photo nor a Video")
        self.navigationController?.popViewController(animated: true)
        self.popDismiss(animated: true)
      }
      return
    }
    
    self.updateAllUIDisplayed()
  }
}
