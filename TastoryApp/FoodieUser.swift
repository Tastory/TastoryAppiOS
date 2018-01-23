//
//  FoodieUser.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-03.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//


import Parse
import ParseFacebookUtilsV4
import FacebookCore
import FacebookLogin
import FacebookShare


class FoodieUser: PFUser {

  // PFUser Freebie Fields
  // @NSManaged var username: String!
  // @NSManaged var password: String!
  // @NSManaged var email: String!
  
  // User Information
  @NSManaged var fullName: String?
  @NSManaged var location: String?  // Format of this shall be enforced by the UI, not by the data structure
  @NSManaged var biography: String?
  @NSManaged var url: String?
  @NSManaged var profileMediaFileName: String?  // File name for the media photo or video. Needs to go with the media object
  @NSManaged var profileMediaType: String?  // Really an enum saying whether it's a Photo or Video
  
  // User Properties
  @NSManaged var isFacebookOnly: Bool
  @NSManaged var roleLevel: Int
  //@NSManaged var authoredStories: PFRelation<PFObject>
  
  // History & Bookmarks
  //@NSManaged var historyStories: PFRelation<PFObject>
  //@NSManaged var bookmarkStories: PFRelation<PFObject>
  
  // Social Connections
  //@NSManaged var followingUsers: PFRelation<PFObject>
  //@NSManaged var followerUsers: PFRelation<PFObject>
  
  // User Settings
  @NSManaged var saveOriginalsToLibrary: Bool
  
  // Notification Settings - TBD
  
  
  // MARK: - Constants
  struct Constants {
    static let MinUsernameLength = 3
    static let MaxUsernameLength = 20
    static let MinPasswordLength = 8
    static let MaxPasswordLength = 32
    static let MinEmailLength = 6
    static let basicFacebookReadPermission = ["public_profile", "user_friends", "email"]
    static let facebookProfilePicWidth = 720
  }

  
  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case loginFoodieUserNil
    
    case facebookLoginFoodieUserNil
    case facebookCurrentAccessTokenNil
    case facebookGraphRequestFailed
    case facebookAccountNoUserId
    case facebookAccountNoEmail
    case parseFacebookCheckEmailFailed
    case parseFacebookEmailRegistered
    
    case facebookLinkNotCurrentUser
    case facebookLinkAlreadyUsed
    case facebookGraphRequestNoName
    
    case invalidSessionToken
    
    case usernameIsEmpty
    case usernameTooShort(Int)
    case usernameTooLong(Int)
    case usernameContainsSpace
    case usernameContainsSymbol(String)
    case usernameContainsSeq
    case usernameContainsSuffix(String)
    case usernameReserved
    
    case emailIsEmpty
    case emailIsTaken
    case emailIsInvalid
    
    case passwordIsEmpty
    case passwordTooShort(Int)
    case passwordTooLong(Int)
    case passwordContainsNoLetters
    case passwordContainsUsername
    case passwordContainsEmail
    case passwordContainsSeq(String)
    case passwordContainsRepeat
    
    case getUserForEmailNone
    case getUserForEmailTooMany
    
    case reverificationEmailNil
    case reverficiationVerified
    
    case checkVerificationNoProperty
    
    case operationCancelled
    
    
    var errorDescription: String? {
      switch self {
      case .loginFoodieUserNil:
        return NSLocalizedString("User returned by login is nil", comment: "Error message upon Login")
        
      case .facebookLoginFoodieUserNil:
        return NSLocalizedString("User returned by Facebook login is nil", comment: "Error message upon Login")
      case .facebookCurrentAccessTokenNil:
        return NSLocalizedString("Current Facebook Access Token is nil", comment: "Error message upon Login")
      case .facebookGraphRequestFailed:
        return NSLocalizedString("Facebook Graph Request failed", comment: "Error message upon Login")
      case .facebookAccountNoUserId:
        return NSLocalizedString("Facebook Account has no User ID", comment: "Error message upon Login")
      case .facebookAccountNoEmail:
        return NSLocalizedString("Facebook Account has no E-mail Address. An E-mail address is required for a Tastory Account", comment: "Error message upon Login")
      case .parseFacebookCheckEmailFailed:
        return NSLocalizedString("Checking Facebook E-mail against Parse for availability failed", comment: "Error message upon Login")
      case .parseFacebookEmailRegistered:
        return NSLocalizedString("E-mail associated with the Facebook account is already registered. Please login with your E-mail to link your account to Facebook, so you can login via Facebook in the future.", comment: "Error message upon Login")
        
      case .facebookLinkAlreadyUsed:
        return NSLocalizedString("Facebook account already associated with another Tastory account. Unlink from, or delete the other Tastory account if you want to link the Facebook account to this one.", comment: "Error message upon FB Link")
      case .facebookLinkNotCurrentUser:
        return NSLocalizedString("Not logged in, cannot link against Facebook account", comment: "Error message upon FB Link")
      case .facebookGraphRequestNoName:
        return NSLocalizedString("Facebook Graph Request Response returned no 'name' field", comment: "Error message upon FB Link")
        
      case .invalidSessionToken:
        return NSLocalizedString("User Session Token is invalid", comment: "Error message on PF action that requires User Session Token")
        
      case .usernameIsEmpty:
        return NSLocalizedString("Username is empty", comment: "Error message when Login/ Sign Up fails due to Username problems")
      case .usernameTooShort(let minLength):
        return NSLocalizedString("Username is shorter than minimum length of \(minLength)", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameTooLong(let maxLength):
        return NSLocalizedString("Username is longer than maximum length of \(maxLength)", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameContainsSpace:
        return NSLocalizedString("Username contains space", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameContainsSymbol(let allowedSymbols):
        return NSLocalizedString("Username can only contain symbols of \(allowedSymbols)", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameContainsSeq:
        return NSLocalizedString("Username contains reserved sequence", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameContainsSuffix(let suffix):
        return NSLocalizedString("Username contains reserved suffix of '\(suffix)'", comment: "Error message when Login/Sign Up fails due to Username problems")
      case .usernameReserved:
        return NSLocalizedString("Username reserved", comment: "Error message when Login/ Sign Up fails due to Username problems")
        
      case .emailIsEmpty:
        return NSLocalizedString("E-mail address is empty", comment: "Error message when Sign Up fails")
      case .emailIsTaken:
        return NSLocalizedString("E-mail address is already registered", comment: "Error message when Sign Up fails")
      case .emailIsInvalid:
        return NSLocalizedString("E-mail address is invalid", comment: "Error message when Sign Up fails")
        
      case .passwordIsEmpty:
        return NSLocalizedString("Password is empty", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordTooShort(let minLength):
        return NSLocalizedString("Password is shorter than minimum length of \(minLength)", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordTooLong(let maxLength):
        return NSLocalizedString("Password is longer than maximum length of \(maxLength)", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordContainsNoLetters:
        return NSLocalizedString("Password needs to contain alphabets", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordContainsUsername:
        return NSLocalizedString("Password cannot contain the username", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordContainsEmail:
        return NSLocalizedString("Password cannot contain the E-mail address", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordContainsSeq(let sequence):
        return NSLocalizedString("Password cannot contain sequence '\(sequence)'", comment: "Error message when Login/Sign Up fails due to Password problems")
      case .passwordContainsRepeat:
        return NSLocalizedString("Password cannot contain consecutive repeating characters", comment: "Error message when Login/Sign Up fails due to Password problems")
        
      case .getUserForEmailNone:
        return NSLocalizedString("No FoodieUser amongst Objects returned, or Objects is nil", comment: "Error message when getting Users through E-mail results in problem")
      case .getUserForEmailTooMany:
        return NSLocalizedString("More than 1 FoodieUser in Objects returned", comment: "Error message when getting Users through E-mail results in problem")
        
      case .reverificationEmailNil:
        return NSLocalizedString("No Email for account to reverify on", comment: "Error message when trying to reverify an E-mail address")
      case .reverficiationVerified:
        return NSLocalizedString("Reverfication requested for E-mail already verified", comment: "Error message when trying to reverify an E-mail address")
      case .checkVerificationNoProperty:
        return NSLocalizedString("User has no status for whether E-mail is verified", comment: "Error message when trying to check E-mail verfiication status")
        
      case .operationCancelled:
        return NSLocalizedString("User Operation Cancelled", comment: "Error message for reason why an operation failed")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Types & Enums
  enum OperationType: String {
    case retrieveWhole
    case retrieveRecursive
    case saveWhole
    case saveRecursive
    case saveDigest
    case deleteUser
  }
  
  
  // Story Async Operation Child Class
  class UserAsyncOperation: AsyncOperation {
    
    var operationType: OperationType
    var user: FoodieUser
    var location: FoodieObject.StorageLocation
    var localType: FoodieObject.LocalType
    var forceAnyways: Bool
    var callback: ((Error?) -> Void)?
    
    init(on operationType: OperationType,
         for user: FoodieUser,
         to location: FoodieObject.StorageLocation,
         type localType: FoodieObject.LocalType,
         forceAnyways: Bool = false,
         withBlock callback: ((Error?) -> Void)?) {
      
      self.operationType = operationType
      self.user = user
      self.location = location
      self.localType = localType
      self.forceAnyways = forceAnyways
      self.callback = callback
      super.init()
    }
    
    override func main() {
      CCLog.debug ("User Async \(operationType) Operation \(getUniqueIdentifier()) for \(user.getUniqueIdentifier()) Started.")
      
      switch operationType {
      case .retrieveWhole:
        user.retrieveOpWhole(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .retrieveRecursive:
        user.retrieveOpRecursive(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          // Careful here. Make sure nothing in here can race against anything before this point. In case of a sync callback
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .saveWhole:
        user.saveOpWhole(for: self, to: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .saveRecursive:
        user.saveOpRecursive(for: self, to: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .saveDigest:
        user.saveOpDigest(for: self, to: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .deleteUser:
        user.deleteOpRecursive(for: self, from: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
      }
    }
    
    override func cancel() {
      stateQueue.async {
        // Cancel regardless
        super.cancel()
        
        CCLog.debug("Cancel for User \(self.user.getUniqueIdentifier()), Executing = \(self.isExecuting)")
        
        if self.isExecuting {
          SwiftMutex.lock(&self.user.criticalMutex)
          
          // Cancel all child operations
          for operation in self.childOperations {
            operation.cancel()
          }
          
          switch self.operationType {
          case .retrieveWhole:
            self.user.cancelRetrieveOpRecursive()
          case .saveWhole, .saveRecursive, .saveDigest:
            self.user.cancelSaveOpRecursive()
          default:
            break
          }
          SwiftMutex.unlock(&self.user.criticalMutex)
          
        } else if !self.isFinished {
          self.callback?(ErrorCode.operationCancelled)
          //self.finished()  // Calling isFinished when it's not executing causes problems
        }
      }
    }
  }
  
  
  // MARK: - Public Static Variables
  static var current: FoodieUser? { return PFUser.current() as? FoodieUser }
  

  // MARK: - Public Instance Variables
  var foodieObject: FoodieObject!
  
  var media: FoodieMedia? {
    didSet {
      profileMediaFileName = media!.foodieFileName
      profileMediaType = media!.mediaType!.rawValue
    }
  }

  var criticalMutex = SwiftMutex.create()
  
  
  // MARK: - Private Instance Variables
  private var asyncOperationQueue = OperationQueue()
  
  
  
  // MARK: - Public Static Functions
  static func userConfigure(enableAutoUser: Bool) {
    FoodieUser.registerSubclass()
    
    if enableAutoUser {
      PFUser.enableAutomaticUser()
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init()

    foodieObject = FoodieObject()
    foodieObject.delegate = self
    asyncOperationQueue.qualityOfService = .userInitiated
    asyncOperationQueue.maxConcurrentOperationCount = 1
    // media = FoodieMedia()  // retrieve() will take care of this. Don't set this here.
  }
  
  
  // This is the Initializer we will call internally
  convenience init(foodieMedia: FoodieMedia?) {
    self.init()
    
    // didSet does not get called in initialization context...
    if let foodieMedia = foodieMedia {
      self.media = foodieMedia
      profileMediaFileName = foodieMedia.foodieFileName
      profileMediaType = foodieMedia.mediaType!.rawValue
    }
  }
}


  
// MARK: - SignUp, Login, & General Account Management

extension FoodieUser {
  
  // MARK: - Public Static Computed Variables
  
  static var isCurrentRegistered: Bool {
    guard let current = current else {
      return false
    }
    
    if current.isRegistered {
      return true
    } else {
      return false
    }
  }
  
  
  // MARK: - Public Instance Computed Variables
  
  var isRegistered: Bool { return objectId != nil }
  
  var isVerified: Bool {
    if isFacebookLinked {
      return true
    }
    else if let emailVerified = self.object(forKey: "emailVerified") as? Bool, emailVerified {
      return true
    }
    else {
      return false
    }
  }
  

  // MARK: - Public Static Functions
  
  static func logIn(for username: String, using password: String, withBlock callback: UserErrorBlock?) {
    PFUser.logInWithUsername(inBackground: username.lowercased(), password: password) { (user, error) in
      
      if let error = error {
        callback?(nil, error)
        return
      }
      
      guard let foodieUser = user as? FoodieUser else {
        CCLog.warning("User returned by Parse for username: '\(username)' is not of FoodieUser type or nil")
        callback?(nil, ErrorCode.loginFoodieUserNil)
        return
      }
      
      // Update the Default Permission before calling back
      FoodiePermission.setDefaultObjectPermission(for: foodieUser)
      callback?(foodieUser, nil)
    }
  }
  
  
  static func logOutAndDeleteDraft(withBlock callback: SimpleErrorBlock?) {
    
    if let story = FoodieStory.currentStory {
//      // If a previous Save is stuck because of whatever reason (slow network, etc). This coming Delete will never go thru... And will clog everything there-after. So whack the entire local just in case regardless...
//      FoodieObject.deleteAll(from: .draft) { error in
//        if let error = error {
//          CCLog.warning("Deleting All Drafts resulted in Error - \(error.localizedDescription)")
//        }
      
      story.cancelSaveToServerRecursive()
      _ = story.deleteRecursive(from: .both, type: .draft) { error in
        if let error = error {
          CCLog.warning("Problem deleting Draft from Both - \(error.localizedDescription)")
        }
        FoodieStory.removeCurrent()
        FoodiePermission.setDefaultGlobalObjectPermission()
        PFUser.logOutInBackground(block: callback)
      }
      //      }
    } else {
      FoodiePermission.setDefaultGlobalObjectPermission()
      PFUser.logOutInBackground(block: callback)
    }
  }
  
  
  static func checkUserAvailFor(username: String, withBlock callback: BooleanErrorBlock?) {
    guard let userQuery = PFUser.query() else {
      CCLog.assert("Cannot create a query from PFUser")
      return
    }
    
    userQuery.whereKey("username", equalTo: username)
    userQuery.getFirstObjectInBackground { (object, error) in
      
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain, nsError.code == PFErrorCode.errorObjectNotFound.rawValue {
          CCLog.verbose("User with username \(username) not found")
          callback?(true, nil)
          return
        } else {
          CCLog.warning("Get first user with username: \(username) resulted in error - \(error)")
          callback?(true, error)  // Indeterminate. Let the Sign Up process finalize whether the username is indeed available
          return
        }
      }
      
      guard object is PFUser else {
        callback?(true, nil)
        return
      }
      
      callback?(false, nil)
    }
  }
  
  
  static func checkUserAvailFor(email: String, withBlock callback: BooleanErrorBlock?) {
    guard let userQuery = PFUser.query() else {
      CCLog.assert("Cannot create a query from PFUser")
      return
    }
    
    userQuery.whereKey("email", equalTo: email)
    userQuery.getFirstObjectInBackground { (object, error) in
      
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain, nsError.code == PFErrorCode.errorObjectNotFound.rawValue {
          CCLog.verbose("User with E-mail \(email) not found")
          callback?(true, nil)
          return
        } else {
          CCLog.warning("Get first user with e-mail: \(email) resulted in error - \(error)")
          callback?(true, error)  // Indeterminate. Let the Sign Up process finalize whether the username is indeed available
          return
        }
      }
      
      guard object is PFUser else {
        callback?(true, nil)
        return
      }
      
      callback?(false, nil)
    }
  }
  
  
  static func checkValidFor(username: String) -> ErrorCode? {
    if username.count < Constants.MinUsernameLength {
      return .usernameTooShort(Constants.MinUsernameLength)
    }
    
    if username.count > Constants.MaxUsernameLength {
      return .usernameTooLong(Constants.MaxUsernameLength)
    }
    
    if username.contains(" ") {
      return .usernameContainsSpace
    }
    
    if username.range(of: Restriction.RsvdUsernameCharRegex, options: .regularExpression) != nil {
      return .usernameContainsSymbol(Restriction.AllowedUsernameSymbols)
    }
    
    for sequence in Restriction.RsvdUsernameSeqs {
      if username.contains(sequence) {
        return .usernameContainsSeq
      }
    }
    
    for suffix in Restriction.RsvdUsernameSuffix {
      if username.hasSuffix(suffix) {
        return .usernameContainsSuffix(suffix)
      }
    }
    
    for rsvdName in Restriction.RsvdUsernames {
      if username.lowercased() == rsvdName.lowercased() {
        return .usernameReserved
      }
    }
    
    return nil
  }
  
  
  static func checkValidFor(email: String) -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
    return emailTest.evaluate(with: email)
  }
  
  
  static func checkValidFor(password: String, username: String?, email: String?) -> ErrorCode? {
    
    if password.count < Constants.MinPasswordLength {
      return .passwordTooShort(Constants.MinPasswordLength)
    }
    
    if password.count > Constants.MaxPasswordLength {
      return .passwordTooLong(Constants.MaxPasswordLength)
    }
    
    let letterRange = password.rangeOfCharacter(from: NSCharacterSet.letters)
    
    if letterRange == nil {
      return .passwordContainsNoLetters
    }
    
    if let username = username {
      if password.lowercased().contains(username.lowercased()) {
        return .passwordContainsUsername
      }
    }
    
    if let email = email, checkValidFor(email: email) {
      let localPart = email.components(separatedBy: "@")[0]
      if password.lowercased().contains(localPart.lowercased()) {
        return .passwordContainsEmail
      }
    }
    
    for sequence in Restriction.RsvdPasswordSeqs {
      if password.lowercased().contains(sequence.lowercased()) {
        return .passwordContainsSeq(sequence)
      }
    }
    
    if password.range(of: "(.)\\1{2,}", options: .regularExpression) != nil {  // Catches repeat of over 2 times for any character
      return .passwordContainsRepeat
    }
    
    return nil
  }
  
  
  static func getUserFor(email: String, withBlock callback: AnyErrorBlock?) {
    guard let userQuery = PFUser.query() else {
      CCLog.assert("Cannot create a query from PFUser")
      return
    }
    
    userQuery.whereKey("email", equalTo: email)
    userQuery.findObjectsInBackground { (objects, error) in
      
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain, nsError.code == PFErrorCode.errorObjectNotFound.rawValue {
          CCLog.verbose("User with E-mail \(email) not found")
          callback?(nil, nil)
          return
        } else {
          CCLog.warning("Find user with e-mail: \(email) resulted in error - \(error)")
          callback?(nil, error)  // Indeterminate. Let the Sign Up process finalize whether the username is indeed available
          return
        }
      }
      
      guard let users = objects as? [FoodieUser] else {
        CCLog.warning("Find user with e-mail: \(email) resulted in no FoodieUsers")
        callback?(nil, ErrorCode.getUserForEmailNone)
        return
      }
      
      guard users.count == 1 else {
        CCLog.warning("Find user with e-mail: \(email) resulted in more than 1 FoodieUsers")
        callback?(nil, ErrorCode.getUserForEmailTooMany)
        return
      }
      
      callback?(users[0] as Any, nil)
    }
  }
  
  
  static func resetPassword(with email: String, withBlock callback: SimpleErrorBlock?) {
    PFUser.requestPasswordResetForEmail(inBackground: email) { (success, error) in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  private func signUpSuccess(withBlock callback: SimpleErrorBlock? = nil) {
    
    // Sign Up was successful. Try to add the user to the agreed upon role
    let defaultLevel = FoodieRole.Level.limitedUser
    self.roleLevel = defaultLevel.rawValue
    
    FoodieRole.addUser(self, to: defaultLevel) { error in
      
      if let error = error {
        CCLog.warning("Failed to add User to Role database. Please contact an Administrator - \(error.localizedDescription)")
        
        // Best effort delete of the user
        self.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
        callback?(error)
        return
      }
      
      // Set default Foodie User ACL attribute
      self.acl = FoodiePermission.getDefaultUserPermission(for: self) as PFACL
      
      // Save the change in User ACL
      self.saveWhole(to: .both, type: .cache) { error in
        if error != nil {
          // Total Sign Up Success Finally! Let's change the default ACL to the user class before calling back.
          FoodiePermission.setDefaultObjectPermission(for: self)
        }
        callback?(error)
      }
    }
  }
  
  
  // MARK: - Public Instance Functions
  
//  func forceEmailUnverified() {
//    self.setObject(false, forKey: "emailVerified")
//  }
  

  func signUp(withBlock callback: SimpleErrorBlock?) {
    
    guard var username = username else {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(ErrorCode.usernameIsEmpty)
      }
      return
    }
    
    guard var email = email else {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(ErrorCode.emailIsEmpty)
      }
      return
    }
    
    guard let password = password else {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(ErrorCode.passwordIsEmpty)
      }
      return
    }
    
    if let error = FoodieUser.checkValidFor(username: username) {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(error)
      }
      return
    }
    
    if !FoodieUser.checkValidFor(email: email) {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(ErrorCode.emailIsInvalid)
      }
      return
    }
    
    if let error = FoodieUser.checkValidFor(password: password, username: username, email: email) {
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(error)
      }
      return
    }
    
    // Enforce lowercase
    username = username.lowercased()
    email = email.lowercased()
    
    // Set role of the user first before trying to figure out ACL
    // self.roleLevel = FoodieRole.Level.limitedUser.rawValue
    
    // Now try to Sign Up!
    self.signUpInBackground { (success, error) in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error) { error in
        
        if let error = error {
          CCLog.warning("Failed Signing Up in Background due to Error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        self.isFacebookOnly = false
        self.signUpSuccess(withBlock: callback)
      }
    }
  }
  
  
  func logOutAndDeleteDraft(withBlock callback: SimpleErrorBlock?) {
    FoodieUser.logOutAndDeleteDraft(withBlock: callback)
  }
  
  
  func checkIfEmailVerified(withBlock callback: BooleanErrorBlock?) {
    
    if isVerified {
      DispatchQueue.global(qos: .userInitiated).async { callback?(true, nil) }
      return  // Early return if it's true
    
    // Otherwise, let's double check against the server
    } else {
      retrieveFromLocalThenServer(forceAnyways: true, type: .cache) { error in
        if let error = error {
          
          let nsError = error as NSError
          if nsError.domain == PFParseErrorDomain, let pfErrorCode = PFErrorCode(rawValue: nsError.code) {
            switch pfErrorCode {
            case .errorFacebookInvalidSession:
              CCLog.warning("Invalid Facebook Session Token when retrieving PFUser details")
              fallthrough
            case .errorInvalidSessionToken:
              CCLog.warning("Invalid Session Token when retrieving PFUser details")
              callback?(false, ErrorCode.invalidSessionToken)
              return
            default:
              break
            }
          }
          
          CCLog.warning("Error retrieving PFUser details - \(error.localizedDescription)")
          callback?(false, error)
          return
        }
      
        guard let emailVerified = self.object(forKey: "emailVerified") as? Bool else {
          CCLog.warning("Cannot get PFUser key 'emailVerified'")
          callback?(false, ErrorCode.checkVerificationNoProperty)
          return
        }
        
        callback?(emailVerified, nil)
      }
    }
  }
  
  
  func resendEmailVerification(withBlock callback: SimpleErrorBlock?) {
    guard let email = email else {
      CCLog.assert("No E-mail address for accoung with username: \(username ?? "")")
      DispatchQueue.global(qos: .userInitiated).async {
        callback?(ErrorCode.reverificationEmailNil)
      }
      return
    }
    
    checkIfEmailVerified { (verified, error) in
      if verified {
        CCLog.info("Tried to resend E-mail verification when the E-mail address \(email) is already verified")
        callback?(ErrorCode.reverficiationVerified)
        return
        
      } else {
        let unverifiedEmail = email
        self.email = ""
        self.email = unverifiedEmail
        
        self.saveInBackground { (success, error) in
          FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
        }
      }
    }
  }
}



// MARK: - Facebook SignUp Login Specifics

extension FoodieUser {
  
  // MARK: - Public Instance Computed Variables
  
  var isFacebookLinked: Bool {
    return PFFacebookUtils.isLinked(with: self)
  }
  
  
  // MARK: - Public Static Functions
  
  static func facebookLogIn(withReadPermissions permissions: [String] = Constants.basicFacebookReadPermission,
                            withBlock callback: UserErrorBlock?) {
    
    LoginManager().logOut()  // This is to resolve cases of Facebook User Mismatch Error (304)
    PFFacebookUtils.logInInBackground(withReadPermissions: permissions) { (user, error) in
      if let error = error {
        
//        let nsError = error as? NSError
//        if nsError.domain == FBSDKLoginErrorDomain, nsError.code == FBSDKLoginErrorCode.userMismatchErrorCode {
//
//        }
        
        callback?(nil, error)
        return
      }
      
      guard let foodieUser = user as? FoodieUser else {
        CCLog.warning("User returned from Facebook login is not of FoodieUser type or nil")
        callback?(nil, ErrorCode.facebookLoginFoodieUserNil)
        return
      }
      
      if foodieUser.isNew {
        
        // Do not allow FB log-in for users with the same E-mail address
        guard let fbToken = AccessToken.current else {
          CCLog.warning("User just signed-in, but no current FB Access Token")
          foodieUser.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
          callback?(nil, ErrorCode.facebookCurrentAccessTokenNil)
          return
        }
        
        // This is a new user signup! But we gotta verify whether this FB account have the minimum amount of info before proceeding further
        var graphPath: String
        if let userId = fbToken.userId {
          graphPath = "/\(userId)"
        } else {
          graphPath = "/me"
        }
        
        let parameters: [String : Any] = ["fields" : "name, email, picture.height(\(Constants.facebookProfilePicWidth))"]
        let graphRequest = GraphRequest(graphPath: graphPath, parameters: parameters, accessToken: fbToken)
        let graphConnection = GraphRequestConnection()
        
        graphConnection.add(graphRequest) { response, result in
          switch result {
          case .failed(let error):
            CCLog.warning("Facebook Graph Request Failed: \(error)")
            foodieUser.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
            callback?(nil, ErrorCode.facebookGraphRequestFailed)
            return
            
          case .success(let response):
            CCLog.debug("Facebook Graph Request Succeeded: \(response)")
            
            guard let email = response.dictionaryValue?["email"] as? String else {
              CCLog.warning("Facebook Account has no E-mail address")
              foodieUser.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
              callback?(nil, ErrorCode.facebookAccountNoEmail)
              return
            }
            
            // We gotta check if this E-mail is already in-use
            FoodieUser.checkUserAvailFor(email: email) { avail, error in
              
              if let error = error {
                CCLog.warning("Check E-mail Address available failed - \(error.localizedDescription)")
                foodieUser.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
                callback?(nil, ErrorCode.parseFacebookCheckEmailFailed)
                return
              }
              
              if !avail {
                CCLog.warning("E-mail from Facebook already registered")
                foodieUser.deleteFromLocalNServer() { error in if let error = error { CCLog.assert("Even User Clean-up Failed - \(error.localizedDescription)") } }
                callback?(nil, ErrorCode.parseFacebookEmailRegistered)
                return
              }
              
              // Home Free! Populate basic information
              foodieUser.isFacebookOnly = true
              foodieUser.email = email
              
              if let name = response.dictionaryValue?["name"] as? String {
                foodieUser.fullName = name
              }
              
              // This is bonus round. Take it or leave it
              if let pictureDictionary = response.dictionaryValue?["picture"] as? NSDictionary,
                let dataDictionary = pictureDictionary["data"] as? NSDictionary,
                let urlString = dataDictionary["url"] as? String {
                
                guard let profilePicUrl = URL(string: urlString) else {
                  CCLog.warning("Profile Pic URL from Facebook is invalid")
                  foodieUser.signUpSuccess() { error in callback?(foodieUser, error) }
                  return
                }
                
                var profilePicData: Data?
                do {
                  profilePicData = try Data(contentsOf: profilePicUrl)
                } catch {
                  CCLog.warning("Unable to obtain valid data from Profile Pic URL given by Facebook")
                  foodieUser.signUpSuccess() { error in callback?(foodieUser, error) }
                  return
                }
                
                // !!!! Taking a leap of faith that image data from Facebook will be readable and not gianormous
                if let profilePicData = profilePicData {
                  let profilePicMedia = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
                  profilePicMedia.imageMemoryBuffer = profilePicData
                  foodieUser.media = profilePicMedia
                }
              }
              
              // SignUp Success should save the entire User up to Parse, including the profile pic if avail
              foodieUser.signUpSuccess() { error in callback?(foodieUser, error) }
            }
          }
        }
        
        graphConnection.start()
        
      } else {
        // This is a login success. Update the Default Permission before calling back
        FoodiePermission.setDefaultObjectPermission(for: foodieUser)
        callback?(foodieUser, nil)
      }
    }
  }
  
  
  // MARK: - Public Instance Functions
  func unlinkFacebook(withBlock callback: SimpleErrorBlock?) {
    CCLog.info("Unlinking Facebook from Account")
    
    guard let currentUser = FoodieUser.current, self == currentUser else {
      callback?(ErrorCode.facebookLinkNotCurrentUser)
      return
    }
    
    PFFacebookUtils.unlinkUser(inBackground: currentUser) { (success, error) in
      LoginManager().logOut()
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  func linkFacebook(withBlock callback: SimpleErrorBlock?) {
    CCLog.info("Linking Facebook against Account")
    
    guard let currentUser = FoodieUser.current, self == currentUser else {
      callback?(ErrorCode.facebookLinkNotCurrentUser)
      return
    }
    
    LoginManager().logOut()  // This is to resolve cases of Facebook User Mismatch Error (304)
    PFFacebookUtils.linkUser(inBackground: self, withReadPermissions: Constants.basicFacebookReadPermission) { (success, error) in
      if let error = error {
        CCLog.warning("Facebook Link Failed - \(error.localizedDescription)")
        
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain, let pfErrorCode = PFErrorCode(rawValue: nsError.code) {
          
          switch pfErrorCode {
          case PFErrorCode.errorFacebookAccountAlreadyLinked:
            callback?(ErrorCode.facebookLinkAlreadyUsed)
            return
          
          default:
            break
          }
        }
        callback?(error)
        return
      }
      
      if !success {
        CCLog.assert("Success status and Error object mismatch")
      }
      
      guard let fbToken = AccessToken.current else {
        CCLog.warning("User just linked, but no current FB Access Token")
        callback?(ErrorCode.facebookCurrentAccessTokenNil)
        return
      }
      
      // Issuing a Graph Request just to get the Name or Profile Photo if needed
      var graphPath: String
      if let userId = fbToken.userId {
        graphPath = "/\(userId)"
      } else {
        graphPath = "/me"
      }
      
      let parameters: [String : Any] = ["fields" : "name, picture.height(\(Constants.facebookProfilePicWidth))"]
      let graphRequest = GraphRequest(graphPath: graphPath, parameters: parameters, accessToken: fbToken)
      let graphConnection = GraphRequestConnection()
      
      graphConnection.add(graphRequest) { response, result in
        switch result {
        case .failed(let error):
          CCLog.warning("Facebook Graph Request Failed: \(error)")
          callback?(nil)  // We are not gonna unlink the account just becasue the Graph Request failed
          return
          
        case .success(let response):
          CCLog.debug("Facebook Graph Request Succeeded: \(response)")
          
          if self.fullName == nil, let name = response.dictionaryValue?["name"] as? String {
            self.fullName = name
          }
          
          if currentUser.profileMediaFileName == nil,
            let pictureDictionary = response.dictionaryValue?["picture"] as? NSDictionary,
            let dataDictionary = pictureDictionary["data"] as? NSDictionary,
            let urlString = dataDictionary["url"] as? String {
            
            guard let profilePicUrl = URL(string: urlString) else {
              CCLog.warning("Profile Pic URL from Facebook is invalid")
              self.saveWhole(to: .both, type: .cache, withBlock: callback)
              return
            }
            
            var profilePicData: Data?
            do {
              profilePicData = try Data(contentsOf: profilePicUrl)
            } catch {
              CCLog.warning("Unable to obtain valid data from Profile Pic URL given by Facebook")
              self.saveWhole(to: .both, type: .cache, withBlock: callback)
              return
            }
            
            // !!!! Taking a leap of faith that image data from Facebook will be readable and not gianormous
            if let profilePicData = profilePicData {
              let profilePicMedia = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
              profilePicMedia.imageMemoryBuffer = profilePicData
              self.media = profilePicMedia
            }
          }
          
          // SignUp Success should save the entire User up to Parse, including the profile pic if avail
          self.saveWhole(to: .both, type: .cache, withBlock: callback)
        }
      }
      
      graphConnection.start()
    }
  }
  
  
  func getFacebookName(withBlock callback: AnyErrorBlock?) {
    
    CCLog.debug("Get Facebook Name")
    
    guard let currentUser = FoodieUser.current, self == currentUser else {
      CCLog.warning("No Current User")
      callback?(nil, ErrorCode.facebookLinkNotCurrentUser)
      return
    }

    // Do not allow FB log-in for users with the same E-mail address
    guard let fbToken = AccessToken.current else {
      CCLog.warning("No current FB Access Token")
      callback?(nil, ErrorCode.facebookCurrentAccessTokenNil)
      return
    }
    
    var graphPath: String
    if let userId = fbToken.userId {
      graphPath = "/\(userId)"
    } else {
      graphPath = "/me"
    }
      
    let parameters: [String : Any] = ["fields" : "name"]
    let graphRequest = GraphRequest(graphPath: graphPath, parameters: parameters, accessToken: fbToken)
    let graphConnection = GraphRequestConnection()
      
    graphConnection.add(graphRequest) { response, result in
      switch result {
      case .failed(let error):
        CCLog.warning("Facebook Graph Request Failed: \(error)")
        callback?(nil, ErrorCode.facebookGraphRequestFailed)
        return
        
      case .success(let response):
        CCLog.debug("Facebook Graph Request Succeeded: \(response)")
        
        guard let name = response.dictionaryValue?["name"] as? String else {
          CCLog.warning("Facebook Graph Request did not return field 'Name'")
          callback?(nil, ErrorCode.facebookGraphRequestNoName)
          return
        }
        callback?(name, nil)
      }
    }
    graphConnection.start()
  }
}



// MARK: - Properties Manipulation Functions
  
extension FoodieUser {
  
  // Force Queries to be done out of the FoodieQuery class?
  
  
  // MARK: - Public Instance Computed Variables
  
  var defaultDiscoverability: FoodieStory.Discoverability {
    if roleLevel >= FoodieRole.Level.user.rawValue {
      return .normal
    } else {
      return .limited
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  func addAuthoredStory(_ story: FoodieStory, withBlock callback: SimpleErrorBlock?) {
    // Do a retrieve before adding
    retrieveFromLocalThenServer(forceAnyways: true, type: .cache) { error in
      if let error = error {
        CCLog.warning("Retrieve for add authored story failed - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      let relation = self.relation(forKey: "authoredStories")
      relation.add(story)
      
      self.saveToLocalNServer(type: .cache) { error in
        if let error = error {
          CCLog.warning("Save for add authored story failed - \(error.localizedDescription)")
        }
        callback?(error)
      }
    }
  }
  
  func removeAuthoredStory(_ story: FoodieStory, withBlock callback: SimpleErrorBlock?) {
    // Do a retrieve before adding
    retrieveFromLocalThenServer(forceAnyways: true, type: .cache) { error in
      if let error = error {
        CCLog.warning("Retrieve for add authored story failed - \(error.localizedDescription)")
        callback?(error)
        return
      }
      let relation = self.relation(forKey: "authoredStories")
      relation.remove(story)
      
      self.saveToLocalNServer(type: .cache) { error in
        if let error = error {
          CCLog.warning("Save for add authored story failed - \(error.localizedDescription)")
        }
        callback?(error)
      }
    }
  }
  
//  func addHistoryStory(_ story: FoodieStory) {
//    if historyStories == nil {
//      historyStories = PFRelation<FoodieStory>()
//    }
//    historyStories!.add(story)
//  }
//  
//  func removeHistoryStory(_ story: FoodieStory) {
//    guard let historyStories = authoredStories else {
//      CCLog.fatal("Cannot remove from a nil historyStories relation")
//    }
//    historyStories.remove(story)
//  }
//  
//  func addBookmarkStory(_ story: FoodieStory) {
//    if bookmarkStories == nil {
//      bookmarkStories = PFRelation<FoodieStory>()
//    }
//    bookmarkStories!.add(story)
//  }
//  
//  func removeBookmarkStory(_ story: FoodieStory) {
//    guard let bookmarkStories = bookmarkStories else {
//      CCLog.fatal("Cannot remove from a nil bookmarkStories relation")
//    }
//    bookmarkStories.remove(story)
//  }
//  
//  func addFollowingUser(_ user: FoodieUser) {
//    if followingUsers == nil {
//      followingUsers = PFRelation<FoodieUser>()
//    }
//    followingUsers!.add(user)
//  }
//  
//  func removeFollowingUser(_ user: FoodieUser) {
//    guard let followingUsers = followingUsers else {
//      CCLog.fatal("Cannot remove from a nil followingUsers relation")
//    }
//    followingUsers.remove(user)
//  }
//  
//  func addFollowerUser(_ user: FoodieUser) {
//    if followerUsers == nil {
//      followerUsers = PFRelation<FoodieUser>()
//    }
//    followerUsers!.add(user)
//  }
//  
//  func removeFollowerUser(_ user: FoodieUser) {
//    guard let followerUsers = followerUsers else {
//      CCLog.fatal("Cannot remove from a nil followerUsers relation")
//    }
//    followerUsers.remove(user)
//  }
}



// MARK: - Foodie Object Delegate Protocol Conformance

extension FoodieUser: FoodieObjectDelegate {
  
  // MARK: - Public Instance Computed Variables
  
  var isRetrieved: Bool { return isDataAvailable }

  var isFullyRetrieved: Bool {
    guard isDataAvailable else {
      return false  // Don't go further if the parent isn't even retrieved
    }
    
    if let media = media {
      return media.isRetrieved
    }
    return true
  }

  
  // MARK: - Public Static Functions
  
  static func deleteAll(from localType: FoodieObject.LocalType,
                        withBlock callback: SimpleErrorBlock?) {
    unpinAllObjectsInBackground(withName: localType.rawValue) { success, error in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  static func cancelAll() { return }  // Nothing to cancel on for PFUser types
  
  
  // MARK: - Private Instance Functions
  
  // Retrieves just the user itself
  private func retrieve(from location: FoodieObject.StorageLocation,
                        type localType: FoodieObject.LocalType,
                        forceAnyways: Bool,
                        withBlock callback: SimpleErrorBlock?) {
    
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if self.media == nil, let fileName = self.profileMediaFileName,
        let typeString = self.profileMediaType, let type = FoodieMediaType(rawValue: typeString) {
        self.media = FoodieMedia(for: fileName, localType: localType, mediaType: type)
      }
      
      callback?(error)  // Callback regardless
    }
  }
  
  
  private func retrieveOpRecursive(for userOperation: UserAsyncOperation,
                                   from location: FoodieObject.StorageLocation,
                                   type localType: FoodieObject.LocalType,
                                   forceAnyways: Bool,
                                   withReady readyBlock: SimpleBlock? = nil,
                                   withCompletion callback: SimpleErrorBlock?) {
    
    CCLog.warning("Parent PFObject shouldn't need to call retrieveRecursive on Users if the parent object is obtained through a query+include")
    
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.warning("User.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      readyBlock?()
      callback?(nil)
    }
  }
  
  
  private func retrieveOpWhole(for userOperation: UserAsyncOperation,
                               from location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               forceAnyways: Bool,
                               withReady readyBlock: SimpleBlock? = nil,
                               withCompletion callback: SimpleErrorBlock?) {
    
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("User.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 0
      
      if self.media != nil { outstandingChildOperations += 1 }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !userOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      guard outstandingChildOperations != 0 else {
        readyBlock?()
        callback?(nil)
        return
      }
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      
      if let media = self.media {
        self.foodieObject.retrieveChild(media, from: location, type: localType, forceAnyways: forceAnyways, for: userOperation, withReady: readyBlock, withCompletion: callback)
      }
    }
  }
  
  
  // This is if a parent object calls for Save
  private func saveOpRecursive(for userOperation: UserAsyncOperation,
                               to location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               withBlock callback: SimpleErrorBlock?) {
    
    // Calculate how many outstanding children operations there will be before hand
    // This helps avoiding the need of a lock
    var outstandingChildOperations = 0
    
    if self.media != nil { outstandingChildOperations += 1 }
    
    // Can we just use a mutex lock then?
    SwiftMutex.lock(&criticalMutex)
    defer { SwiftMutex.unlock(&criticalMutex) }
    
    guard !userOperation.isCancelled else {
      callback?(ErrorCode.operationCancelled)
      return
    }
    
    guard outstandingChildOperations != 0 else {
      callback?(nil)
      return
    }
    
    foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
    
    if let media = self.media {
      self.foodieObject.saveChild(media, to: location, type: localType, for: userOperation, withBlock: callback)
    }
  }
  
  
  // This is if an external object calls for Save of User and all sub-objects
  private func saveOpWhole(for userOperation: UserAsyncOperation,
                           to location: FoodieObject.StorageLocation,
                           type localType: FoodieObject.LocalType,
                           withBlock callback: SimpleErrorBlock?) {
    
    // Calculate how many outstanding children operations there will be before hand
    // This helps avoiding the need of a lock
    var outstandingChildOperations = 0
    
    if let media = self.media, media.isRetrieved { outstandingChildOperations += 1 }
    
    // Can we just use a mutex lock then?
    SwiftMutex.lock(&criticalMutex)
    defer { SwiftMutex.unlock(&criticalMutex) }
    
    guard !userOperation.isCancelled else {
      callback?(ErrorCode.operationCancelled)
      return
    }
    
    guard outstandingChildOperations != 0 else {
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      return
    }
    
    foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
    
    if let media = self.media, media.isRetrieved {
      self.foodieObject.saveChild(media, to: location, type: localType, for: userOperation) { error in
        self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      }
    }
  }
  
  
  // This is if an external object just want to Save the Digest, in this case just the User PFObject
  private func saveOpDigest(for userOperation: UserAsyncOperation,
                            to location: FoodieObject.StorageLocation,
                            type localType: FoodieObject.LocalType,
                            withBlock callback: SimpleErrorBlock?) {
    
    guard !userOperation.isCancelled else {
      callback?(ErrorCode.operationCancelled)
      return
    }
    foodieObject.saveObject(to: location, type: localType, withBlock: callback)
  }
  
  
  private func deleteOpRecursive(for userOperation: UserAsyncOperation,
                                 from location: FoodieObject.StorageLocation,
                                 type localType: FoodieObject.LocalType,
                                 withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve the User (only) to guarentee access to the childrens
    retrieve(from: location, type: localType, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("User.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      // Delete self first before deleting children
      self.foodieObject.deleteObject(from: location, type: localType) { error in
        
        if let error = error {
          CCLog.warning("Deleting self resulted in error: \(error.localizedDescription)")
          
          // Do best effort delete of all children
          if let media = self.media {
            self.foodieObject.deleteChild(media, from: location, type: localType, for: nil, withBlock: nil)
          }
          
          // Just callback with the error
          callback?(error)
          return
        }
        
        // Calculate how many outstanding children operations there will be before hand
        // This helps avoiding the need of a lock
        var outstandingChildOperations = 0
        
        if self.media != nil { outstandingChildOperations += 1 }
        
        // Can we just use a mutex lock then?
        SwiftMutex.lock(&self.criticalMutex)
        defer { SwiftMutex.unlock(&self.criticalMutex) }
        
        guard !userOperation.isCancelled else {
          callback?(ErrorCode.operationCancelled)
          return
        }
        
        // If there's no child op, then just delete and return
        guard outstandingChildOperations != 0 else {
          callback?(error)
          return
        }
        
        self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
        
        // check for media and thumbnails to be deleted from this object
        if let media = self.media {
          self.foodieObject.deleteChild(media, from: location, type: localType, for: userOperation, withBlock: callback)
        }
      }
    }
  }
  
  
  private func cancelRetrieveOpRecursive() {
    CCLog.verbose("Cancel Retrieve Recursive for User \(getUniqueIdentifier())")
    
    // ??? Should we really retrieve first? Bandwidth? Collision risk?
    retrieveFromLocalThenServer(forceAnyways: false, type: .cache) { error in
      if let error = error {
        CCLog.assert("User() resulted in error: \(error.localizedDescription)")
        return
      }
      
      if let media = self.media {
        media.cancelRetrieveFromServerRecursive()
      }
    }
  }
  
  
  private func cancelSaveOpRecursive() {
    CCLog.verbose("Cancel Save Recursive for User \(getUniqueIdentifier())")
    
    if let media = media {
      media.cancelSaveToServerRecursive()
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  func retrieveWhole(from location: FoodieObject.StorageLocation,
                      type localType: FoodieObject.LocalType,
                      forceAnyways: Bool = false,
                      for parentOperation: AsyncOperation? = nil,
                      withReady readyBlock: SimpleBlock? = nil,
                      withCompletion callback: SimpleErrorBlock?) {

    let retrieveOperation = UserAsyncOperation(on: .retrieveWhole, for: self, to: location, type: localType, forceAnyways: forceAnyways) { error in
      readyBlock?()
      callback?(error)
    }
    CCLog.debug ("Retrieve User In Whole Operation \(retrieveOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(retrieveOperation)
    asyncOperationQueue.addOperation(retrieveOperation)
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         for parentOperation: AsyncOperation? = nil,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    CCLog.warning("Parent PFObject shouldn't need to call retrieveRecursive on Users if the parent object is obtained through a query+include")
    
    let retrieveOperation = UserAsyncOperation(on: .retrieveRecursive, for: self, to: location, type: localType, forceAnyways: forceAnyways) { error in
      readyBlock?()
      callback?(error)
    }
    CCLog.debug ("Retrieve User Recursive Operation \(retrieveOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(retrieveOperation)
    asyncOperationQueue.addOperation(retrieveOperation)
    return retrieveOperation
  }
  
  
  // This is if an external object calls for Save of User and all sub-objects
  func saveWhole(to location: FoodieObject.StorageLocation,
                  type localType: FoodieObject.LocalType,
                  for parentOperation: AsyncOperation? = nil,
                  withBlock callback: SimpleErrorBlock?) {
    
    let saveOperation = UserAsyncOperation(on: .saveWhole, for: self, to: location, type: localType, withBlock: callback)
    CCLog.debug ("Save User In Whole Operation \(saveOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(saveOperation)
    asyncOperationQueue.addOperation(saveOperation)
  }
  
  
  // This is if a parent object calls for Save
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation? = nil,
                     withBlock callback: SimpleErrorBlock?) {
    
    let saveOperation = UserAsyncOperation(on: .saveRecursive, for: self, to: location, type: localType, withBlock: callback)
    CCLog.debug ("Save User Recursive Operation \(saveOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(saveOperation)
    asyncOperationQueue.addOperation(saveOperation)
  }
  
  
  // This is if an external object just want to Save the Digest, in this case just the User PFObject
  func saveDigest(to location: FoodieObject.StorageLocation,
                  type localType: FoodieObject.LocalType,
                  for parentOperation: AsyncOperation? = nil,
                  withBlock callback: SimpleErrorBlock?) {
    
    let saveOperation = UserAsyncOperation(on: .saveDigest, for: self, to: location, type: localType, withBlock: callback)
    CCLog.debug ("Save User Digest Operation \(saveOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(saveOperation)
    asyncOperationQueue.addOperation(saveOperation)
  }
  
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation? = nil,
                       withBlock callback: SimpleErrorBlock?) {
    
    let deleteOperation = UserAsyncOperation(on: .deleteUser, for: self, to: location, type: localType, withBlock: callback)
    CCLog.debug ("Delete User Recursive Operation \(deleteOperation.getUniqueIdentifier()) for \(getUniqueIdentifier()) Queued")
    parentOperation?.add(deleteOperation)
    asyncOperationQueue.addOperation(deleteOperation)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    CCLog.info("Cancel All Rerieval (All Operations!) for User \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
  }
  
  
  func cancelSaveToServerRecursive() {
    CCLog.info("Cancel All Save (All Operations!) for User \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))  }
  
  
  func foodieObjectType() -> String {
    return "FoodieUser"
  }

  
  // MARK: - Basic CRUD ~ Retrieve/Save/Delete   // TODO: Should really try to merge with FoodiePFObject. Make everything into another Protocol?
  
  func retrieve(from localType: FoodieObject.LocalType,
                forceAnyways: Bool,
                withBlock callback: SimpleErrorBlock?) {
    
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {
      CCLog.debug("\(delegate.foodieObjectType())(\(getUniqueIdentifier())) Data Available and not Forcing Anyways. Calling back with nil")
      callback?(nil)
      return
    }
    
    // See if this is in local
    CCLog.debug("Fetching \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from \(localType) In Background")
    fetchFromLocalDatastoreInBackground { object, error in  // Fetch does not distinguish from where (draft vs cache)
      
      // Error Cases
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
        }
        callback?(error)
        return
      }
        
        // No Object or No Data Available
      else if object == nil || self.isDataAvailable == false {
        CCLog.assert("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))")
        callback?(PFErrorCode.errorCacheMiss as? Error)
        return
      }
      
      // Finally the Good Case
      callback?(nil)
    }
    
    
    if forceAnyways {
      self.fetchInBackground { (_, error) in
        callback?(error)
      }
    } else {
      self.fetchIfNeededInBackground { (_, error) in
        callback?(error)
      }
    }
  }

  
  // At the Fetch stage, Parse doesn't care about Draft vs Cache anymore. But this always saves a copy back into Cache if ultimately retrieved from Server
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   type localType: FoodieObject.LocalType,
                                   withReady readyBlock: SimpleBlock? = nil,
                                   withCompletion callback: SimpleErrorBlock?) {
    
    let fetchRetry = SwiftRetry()
    
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {
      CCLog.debug("\(delegate.foodieObjectType())(\(getUniqueIdentifier())) Data Available and not Forcing Anyways. Calling back with nil")
      callback?(nil)
      return
    }
      
    // If force anyways, try to fetch
    else if forceAnyways {
      CCLog.debug("Forced to fetch \(delegate.foodieObjectType())(\(getUniqueIdentifier())) In Background")
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: FoodiePFObject.Constants.ParseRetryCount) {
        self.fetchInBackground() { object, error in  // This fetch only comes from Server
          if let error = error {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: FoodiePFObject.Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          }
          // Return if got what's wanted
          callback?(error)
          fetchRetry.done()
        }
      }
      return
    }
    
    // See if this is in local cache
    CCLog.debug("Fetch \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from Local Datastore In Background")
    fetchFromLocalDatastoreInBackground { localObject, localError in  // Fetch does not distinguish from where (draft vs cache)
      
      if localError == nil, localObject != nil, self.isDataAvailable == true {
        CCLog.verbose("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) form Local Datastore Error: \(localError?.localizedDescription ?? "Nil"), localObject: \(localObject != nil ? "True" : "False"), DataAvailable: \(self.isDataAvailable ? "True" : "False")")
        callback?(nil)
        return
      }
      
      // Error Cases
      if let error = localError {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
        }
      }
        
        // No Object or No Data Available
      else if localObject == nil || self.isDataAvailable == false {
        CCLog.debug("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))")
      }
      
      // If not in Local Datastore, retrieved from Server
      CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) In Background")
      
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: FoodiePFObject.Constants.ParseRetryCount) { [unowned self] in
        self.fetchIfNeededInBackground { serverObject, serverError in
          if let error = serverError {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())), with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: FoodiePFObject.Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          }
//          else {
//            CCLog.debug("Pin \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) to Name '\(localType)'")
//            self.pinInBackground(withName: localType.rawValue) { (success, error) in FoodieGlobal.booleanToSimpleErrorCallback(success, error, nil) }
//          }
          // Return if got what's wanted
          callback?(serverError)
          fetchRetry.done()
        }
      }
    }
  }
  
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    CCLog.debug("Pin \(delegate.foodieObjectType())(\(getUniqueIdentifier())) to Local with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { success, error in FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Pin \(delegate.foodieObjectType())(\(getUniqueIdentifier())) with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { (success, error) in
      
      guard success || error == nil else {
        FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
        return
      }
      
      CCLog.debug("Save \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) in background")
      
      let saveRetry = SwiftRetry()
      saveRetry.start("Save \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: FoodiePFObject.Constants.ParseRetryCount) {
        
        self.saveInBackground { success, error in
          if !success || error != nil {
            if saveRetry.attempt(after: FoodiePFObject.Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          }
          FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
          saveRetry.done()
        }
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from Local with Name \(localType)")
    unpinInBackground(withName: localType.rawValue) { success, error in FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func deleteFromLocalNServer(withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Delete should also unpin across all namespaces
    CCLog.debug("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier())) in Background")
    
    let deleteRetry = SwiftRetry()
    deleteRetry.start("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier()))", withCountOf: FoodiePFObject.Constants.ParseRetryCount) {
      
      self.deleteInBackground { success, error in
        if !success || error != nil {
          if deleteRetry.attempt(after: FoodiePFObject.Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
        }
        
        // Each call actually goes through a booleanToSimpleErrorCallback(). So will do a CCLog.warning natively. Should just brute force deletes regardless
        FoodieGlobal.booleanToSimpleErrorCallback(success, error) { error in
          self.delete(from: .draft) { error in
            self.delete(from: .cache, withBlock: callback)
          }
        }
        deleteRetry.done()
      }
    }
  }
}



// MARK: - Restriction lists regarding to User Registration

extension FoodieUser {
  struct Restriction {
    static let RsvdUsernames = ["abuse", "admin", "administrator", "domain", "elite", "hostmaster", "leader", "login", "majordomo", "manager", "master", "moderator", "postmaster", "super-admin", "root", "password", "ssl-admin", "username", "webmaster", "4r5e", "5h1t", "5hit", "a55", "anal", "anus", "ar5e", "arrse", "arse", "ass", "ass-fucker", "asses", "assfucker", "assfukka", "asshole", "assholes", "asswhole", "a_s_s", "b!tch", "b00bs", "b17ch", "b1tch", "ballbag", "balls", "ballsack", "bastard", "beastial", "beastiality", "bellend", "bestial", "bestiality", "bi+ch", "biatch", "bitch", "bitcher", "bitchers", "bitches", "bitchin", "bitching", "bloody", "blowjob", "blowjob", "blowjobs", "boiolas", "bollock", "bollok", "boner", "boob", "boobs", "booobs", "boooobs", "booooobs", "booooooobs", "breasts", "buceta", "bugger", "bum", "bunnyfucker", "butt", "butthole", "buttmuch", "buttplug", "c0ck", "c0cksucker", "carpetmuncher", "cawk", "chink", "cipa", "cl1t", "clit", "clitoris", "clits", "cnut", "cock", "cock-sucker", "cockface", "cockhead", "cockmunch", "cockmuncher", "cocks", "cocksuck", "cocksucked", "cocksucker", "cocksucking", "cocksucks", "cocksuka", "cocksukka", "cok", "cokmuncher", "coksucka", "coon", "cox", "crap", "cum", "cummer", "cumming", "cums", "cumshot", "cunilingus", "cunillingus", "cunnilingus", "cunt", "cuntlick", "cuntlicker", "cuntlicking", "cunts", "cyalis", "cyberfuc", "cyberfuck", "cyberfucked", "cyberfucker", "cyberfuckers", "cyberfucking", "d1ck", "damn", "dick", "dickhead", "dildo", "dildos", "dink", "dinks", "dirsa", "dlck", "dog-fucker", "doggin", "dogging", "donkeyribber", "doosh", "duche", "dyke", "ejaculate", "ejaculated", "ejaculates", "ejaculating", "ejaculatings", "ejaculation", "ejakulate", "fuck", "fucker", "f4nny", "fag", "fagging", "faggitt", "faggot", "faggs", "fagot", "fagots", "fags", "fanny", "fannyflaps", "fannyfucker", "fanyy", "fatass", "fcuk", "fcuker", "fcuking", "feck", "fecker", "felching", "fellate", "fellatio", "fingerfuck", "fingerfucked", "fingerfucker", "fingerfuckers", "fingerfucking", "fingerfucks", "fistfuck", "fistfucked", "fistfucker", "fistfuckers", "fistfucking", "fistfuckings", "fistfucks", "flange", "fook", "fooker", "fuck", "fucka", "fucked", "fucker", "fuckers", "fuckhead", "fuckheads", "fuckin", "fucking", "fuckings", "fuckingshitmotherfucker", "fuckme", "fucks", "fuckwhit", "fuckwit", "fudgepacker", "fudgepacker", "fuk", "fuker", "fukker", "fukkin", "fuks", "fukwhit", "fukwit", "fux", "fux0r", "f_u_c_k", "gangbang", "gangbanged", "gangbangs", "gaylord", "gaysex", "goatse", "God", "god-dam", "god-damned", "goddamn", "goddamned", "hardcoresex", "hell", "heshe", "hoar", "hoare", "hoer", "homo", "hore", "horniest", "horny", "hotsex", "jack-off", "jackoff", "jap", "jerk-off", "jism", "jiz", "jizm", "jizz", "kawk", "knob", "knobead", "knobed", "knobend", "knobhead", "knobjocky", "knobjokey", "kock", "kondum", "kondums", "kum", "kummer", "kumming", "kums", "kunilingus", "l3i+ch", "l3itch", "labia", "lmfao", "lust", "lusting", "m0f0", "m0fo", "m45terbate", "ma5terb8", "ma5terbate", "masochist", "master-bate", "masterb8", "masterbat*", "masterbat3", "masterbate", "masterbation", "masterbations", "masturbate", "mo-fo", "mof0", "mofo", "mothafuck", "mothafucka", "mothafuckas", "mothafuckaz", "mothafucked", "mothafucker", "mothafuckers", "mothafuckin", "mothafucking", "mothafuckings", "mothafucks", "motherfucker", "motherfuck", "motherfucked", "motherfucker", "motherfuckers", "motherfuckin", "motherfucking", "motherfuckings", "motherfuckka", "motherfucks", "muff", "mutha", "muthafecker", "muthafuckker", "muther", "mutherfucker", "n1gga", "n1gger", "nazi", "nigg3r", "nigg4h", "nigga", "niggah", "niggas", "niggaz", "nigger", "niggers", "nob", "nobjokey", "nobhead", "nobjocky", "nobjokey", "numbnuts", "nutsack", "orgasim", "orgasims", "orgasm", "orgasms", "p0rn", "pawn", "pecker", "penis", "penisfucker", "phonesex", "phuck", "phuk", "phuked", "phuking", "phukked", "phukking", "phuks", "phuq", "pigfucker", "pimpis", "piss", "pissed", "pisser", "pissers", "pisses", "pissflaps", "pissin", "pissing", "pissoff", "poop", "porn", "porno", "pornography", "pornos", "prick", "pricks", "pron", "pube", "pusse", "pussi", "pussies", "pussy", "pussys", "rectum", "retard", "rimjaw", "rimming", "shit", "s.o.b.", "sadist", "schlong", "screwing", "scroat", "scrote", "scrotum", "semen", "sex", "sh!+", "sh!t", "sh1t", "shag", "shagger", "shaggin", "shagging", "shemale", "shi+", "shit", "shitdick", "shite", "shited", "shitey", "shitfuck", "shitfull", "shithead", "shiting", "shitings", "shits", "shitted", "shitter", "shitters", "shitting", "shittings", "shitty", "skank", "slut", "sluts", "smegma", "smut", "snatch", "son-of-a-bitch", "spac", "spunk", "s_h_i_t", "t1tt1e5", "t1tties", "teets", "teez", "testical", "testicle", "tit", "titfuck", "tits", "titt", "tittie5", "tittiefucker", "titties", "tittyfuck", "tittywank", "titwank", "tosser", "turd", "tw4t", "twat", "twathead", "twatty", "twunt", "twunter", "v14gra", "v1gra", "vagina", "viagra", "vulva", "w00se", "wank", "wanker", "wanky", "whoar", "whore", "willies", "willy", "xrated", "xxx"]
    
    static let RsvdUsernameSeqs = ["fuck", "shit"]
    
    static let RsvdUsernameSuffix = [".js", ".json", ".css", ".html", ".htm", ".xml", ".jpg", ".jpeg", ".h264", ".png", ".gif", ".bmp", ".ico", ".tif", ".tiff", ".woff", "swift", ".m", ".h", ".c", ".mov", ".avi", ".log", ".txt", ".doc", ".xls", ".ppt", ".pdf", ".mp3", ".wav", ".wma", ".pkg", ".rpm", ".rar", ".tar", ".gz", ".zip", ".bin", ".dmg", ".iso", ".csv", ".dat", ".sql", ".php", ".py", ".bat", ".cgi", ".pl", ".com", ".net", ".co", ".org", ".exe", ".jar", ".ttf", ".ai", ".ps", ".psd", ".cgi", ".js", ".rss", ".xhtml", ".asp", ".aspx", ".key", ".pptx", ".class", ".cpp", ".sh", ".vb", ".docx", ".xlsx", ".cfg", ".dll", ".sys", ".tmp", ".msi", ".ini", ".3g2", ".3gp", ".m4v", ".mkv", ".mpg", ".mpeg", ".wmv", ".rtf"]
    
    static let RsvdUsernameCharRegex = "[^0-9a-zA-ZÀ-ÿ\\-_=|:.]"
    static let AllowedUsernameSymbols = "-_=|:."
    
    static let RsvdPasswordSeqs = ["abc", "123", "tastory", "password"]
  }
}
