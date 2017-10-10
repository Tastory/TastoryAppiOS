//
//  FoodieUser.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-03.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Parse


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
  
  // User Properties
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
  
  // Analytics
  @NSManaged var storiesViewed: Int
  @NSManaged var momentsViewed: Int
  
  
  
  // MARK: - Constants
  struct Constants {
    static let MinUsernameLength = 3
    static let MaxUsernameLength = 20
    static let MinPasswordLength = 8
    static let MaxPasswordLength = 32
    static let MinEmailLength = 6
  }

  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case loginFoodieUserNil
    
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
    
    
    var errorDescription: String? {
      switch self {
      case .loginFoodieUserNil:
        return NSLocalizedString("User returned by login is nil", comment: "Error message upon Login")
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
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Static Variables
  static var current: FoodieUser? { return PFUser.current() as? FoodieUser }
  
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
  
  
  
  // MARK: - Public Instance Variables
  var isRegistered: Bool { return objectId != nil }

  
  
  // MARK: - Public Static Functions
  
  static func configure(enableAutoUser: Bool) {

    FoodieUser.registerSubclass()
    
    if enableAutoUser {
      PFUser.enableAutomaticUser()
    }
  }
  
  
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
      // If a previous Save is stuck because of whatever reason (slow network, etc). This coming Delete will never go thru... And will clog everything there-after. So whack the entire local just in case regardless...
      FoodieObject.deleteAll(from: .draft) { error in
        if let error = error {
          CCLog.warning("Deleting All Drafts resulted in Error - \(error.localizedDescription)")
        }
        
        story.deleteRecursive(from: .both, type: .draft) { error in
          if let error = error {
            CCLog.warning("Problem deleting Draft from Both - \(error.localizedDescription)")
          }
          FoodieStory.removeCurrent()
          FoodiePermission.setDefaultGlobalObjectPermission()
          PFUser.logOutInBackground(block: callback)
        }
      }
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
    
    if username.characters.count < Constants.MinUsernameLength {
      return .usernameTooShort(Constants.MinUsernameLength)
    }
    
    if username.characters.count > Constants.MaxUsernameLength {
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
    
    if password.characters.count < Constants.MinPasswordLength {
      return .passwordTooShort(Constants.MinPasswordLength)
    }
    
    if password.characters.count > Constants.MaxPasswordLength {
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
  
  
  
  // MARK: - Public Instance Functions
  
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
    self.roleLevel = FoodieRole.Level.limitedUser.rawValue
    
    // Now try to Sign Up!
    self.signUpInBackground { (success, error) in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error) { error in
        
        if let error = error {
          CCLog.warning("Failed Signing Up in Background due to Error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        // Sign Up was successful. Try to add the user to the agreed upon role
        guard let level = FoodieRole.Level(rawValue: self.roleLevel) else {
          CCLog.fatal("Unrecognized roleLevel value")
        }
        
        FoodieRole.addUser(self, to: level) { error in
          
          if let error = error {
            CCLog.warning("Failed to add User to Role database. Please contact an Administrator - \(error.localizedDescription)")
            
            // Best effort delete of the user
            self.delete(withBlock: nil)
            callback?(error)
            return
          }
          
          // Set default Foodie User ACL attribute
          self.acl = FoodiePermission.getDefaultUserPermission(for: self) as PFACL
          
          // Save the change in User ACL
          self.save  { error in
            if error != nil {
              // Total Sign Up Success Finally! Let's change the default ACL to the user class before calling back.
              FoodiePermission.setDefaultObjectPermission(for: self)
            }
            callback?(error)
          }
        }
      }
    }
  }
  
  
  func logOutAndDeleteDraft(withBlock callback: SimpleErrorBlock?) {
    FoodieUser.logOutAndDeleteDraft(withBlock: callback)
  }
  
  
  func checkIfEmailVerified(withBlock callback: BooleanErrorBlock?) {
    
    if let emailVerified = self.object(forKey: "emailVerified") as? Bool, emailVerified {
      DispatchQueue.global(qos: .userInitiated).async { callback?(true, nil) }
      return  // Early return if it's true
    
    // Otherwise, let's double check against the server
    } else {
      retrieve(forceAnyways: true) { error in
        if let error = error {
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
  
  
  // MARK: - Basic CRUD ~ Retrieve/Save/Delete
  
  func retrieve(forceAnyways: Bool = false, withBlock callback: SimpleErrorBlock?) {
    
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
  
  
  func save(withBlock callback: SimpleErrorBlock?) {
    self.saveInBackground { (success, error) in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  func delete(withBlock callback: SimpleErrorBlock?) {
    self.deleteInBackground { (success, error) in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  
  // MARK: - Properties Manipulation Functions
  
  // Force Queries to be done out of the FoodieQuery class?
  
  func addAuthoredStory(_ story: FoodieStory, withBlock callback: SimpleErrorBlock?) {
    // Do a retrieve before adding
    retrieve(forceAnyways: true) { error in
      if let error = error {
        CCLog.warning("Retrieve for add authored story failed - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      let relation = self.relation(forKey: "authoredStories")
      relation.add(story)
      
      self.save { error in
        if let error = error {
          CCLog.warning("Save for add authored story failed - \(error.localizedDescription)")
        }
        callback?(error)
      }
    }
  }
  
  func removeAuthoredStory(_ story: FoodieStory, withBlock callback: SimpleErrorBlock?) {
    // Do a retrieve before adding
    retrieve(forceAnyways: true) { error in
      if let error = error {
        CCLog.warning("Retrieve for add authored story failed - \(error.localizedDescription)")
        callback?(error)
        return
      }
      let relation = self.relation(forKey: "authoredStories")
      relation.remove(story)
      
      self.save { error in
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



// MARK: - Restriction lists regarding to User Registration

extension FoodieUser {
  struct Restriction {
    static let RsvdUsernames = ["abuse", "admin", "administrator", "domain", "elite", "hostmaster", "leader", "login", "majordomo", "manager", "master", "moderator", "postmaster", "super-admin", "root", "password", "ssl-admin", "username", "webmaster", "4r5e", "5h1t", "5hit", "a55", "anal", "anus", "ar5e", "arrse", "arse", "ass", "ass-fucker", "asses", "assfucker", "assfukka", "asshole", "assholes", "asswhole", "a_s_s", "b!tch", "b00bs", "b17ch", "b1tch", "ballbag", "balls", "ballsack", "bastard", "beastial", "beastiality", "bellend", "bestial", "bestiality", "bi+ch", "biatch", "bitch", "bitcher", "bitchers", "bitches", "bitchin", "bitching", "bloody", "blowjob", "blowjob", "blowjobs", "boiolas", "bollock", "bollok", "boner", "boob", "boobs", "booobs", "boooobs", "booooobs", "booooooobs", "breasts", "buceta", "bugger", "bum", "bunnyfucker", "butt", "butthole", "buttmuch", "buttplug", "c0ck", "c0cksucker", "carpetmuncher", "cawk", "chink", "cipa", "cl1t", "clit", "clitoris", "clits", "cnut", "cock", "cock-sucker", "cockface", "cockhead", "cockmunch", "cockmuncher", "cocks", "cocksuck", "cocksucked", "cocksucker", "cocksucking", "cocksucks", "cocksuka", "cocksukka", "cok", "cokmuncher", "coksucka", "coon", "cox", "crap", "cum", "cummer", "cumming", "cums", "cumshot", "cunilingus", "cunillingus", "cunnilingus", "cunt", "cuntlick", "cuntlicker", "cuntlicking", "cunts", "cyalis", "cyberfuc", "cyberfuck", "cyberfucked", "cyberfucker", "cyberfuckers", "cyberfucking", "d1ck", "damn", "dick", "dickhead", "dildo", "dildos", "dink", "dinks", "dirsa", "dlck", "dog-fucker", "doggin", "dogging", "donkeyribber", "doosh", "duche", "dyke", "ejaculate", "ejaculated", "ejaculates", "ejaculating", "ejaculatings", "ejaculation", "ejakulate", "fuck", "fucker", "f4nny", "fag", "fagging", "faggitt", "faggot", "faggs", "fagot", "fagots", "fags", "fanny", "fannyflaps", "fannyfucker", "fanyy", "fatass", "fcuk", "fcuker", "fcuking", "feck", "fecker", "felching", "fellate", "fellatio", "fingerfuck", "fingerfucked", "fingerfucker", "fingerfuckers", "fingerfucking", "fingerfucks", "fistfuck", "fistfucked", "fistfucker", "fistfuckers", "fistfucking", "fistfuckings", "fistfucks", "flange", "fook", "fooker", "fuck", "fucka", "fucked", "fucker", "fuckers", "fuckhead", "fuckheads", "fuckin", "fucking", "fuckings", "fuckingshitmotherfucker", "fuckme", "fucks", "fuckwhit", "fuckwit", "fudgepacker", "fudgepacker", "fuk", "fuker", "fukker", "fukkin", "fuks", "fukwhit", "fukwit", "fux", "fux0r", "f_u_c_k", "gangbang", "gangbanged", "gangbangs", "gaylord", "gaysex", "goatse", "God", "god-dam", "god-damned", "goddamn", "goddamned", "hardcoresex", "hell", "heshe", "hoar", "hoare", "hoer", "homo", "hore", "horniest", "horny", "hotsex", "jack-off", "jackoff", "jap", "jerk-off", "jism", "jiz", "jizm", "jizz", "kawk", "knob", "knobead", "knobed", "knobend", "knobhead", "knobjocky", "knobjokey", "kock", "kondum", "kondums", "kum", "kummer", "kumming", "kums", "kunilingus", "l3i+ch", "l3itch", "labia", "lmfao", "lust", "lusting", "m0f0", "m0fo", "m45terbate", "ma5terb8", "ma5terbate", "masochist", "master-bate", "masterb8", "masterbat*", "masterbat3", "masterbate", "masterbation", "masterbations", "masturbate", "mo-fo", "mof0", "mofo", "mothafuck", "mothafucka", "mothafuckas", "mothafuckaz", "mothafucked", "mothafucker", "mothafuckers", "mothafuckin", "mothafucking", "mothafuckings", "mothafucks", "motherfucker", "motherfuck", "motherfucked", "motherfucker", "motherfuckers", "motherfuckin", "motherfucking", "motherfuckings", "motherfuckka", "motherfucks", "muff", "mutha", "muthafecker", "muthafuckker", "muther", "mutherfucker", "n1gga", "n1gger", "nazi", "nigg3r", "nigg4h", "nigga", "niggah", "niggas", "niggaz", "nigger", "niggers", "nob", "nobjokey", "nobhead", "nobjocky", "nobjokey", "numbnuts", "nutsack", "orgasim", "orgasims", "orgasm", "orgasms", "p0rn", "pawn", "pecker", "penis", "penisfucker", "phonesex", "phuck", "phuk", "phuked", "phuking", "phukked", "phukking", "phuks", "phuq", "pigfucker", "pimpis", "piss", "pissed", "pisser", "pissers", "pisses", "pissflaps", "pissin", "pissing", "pissoff", "poop", "porn", "porno", "pornography", "pornos", "prick", "pricks", "pron", "pube", "pusse", "pussi", "pussies", "pussy", "pussys", "rectum", "retard", "rimjaw", "rimming", "shit", "s.o.b.", "sadist", "schlong", "screwing", "scroat", "scrote", "scrotum", "semen", "sex", "sh!+", "sh!t", "sh1t", "shag", "shagger", "shaggin", "shagging", "shemale", "shi+", "shit", "shitdick", "shite", "shited", "shitey", "shitfuck", "shitfull", "shithead", "shiting", "shitings", "shits", "shitted", "shitter", "shitters", "shitting", "shittings", "shitty", "skank", "slut", "sluts", "smegma", "smut", "snatch", "son-of-a-bitch", "spac", "spunk", "s_h_i_t", "t1tt1e5", "t1tties", "teets", "teez", "testical", "testicle", "tit", "titfuck", "tits", "titt", "tittie5", "tittiefucker", "titties", "tittyfuck", "tittywank", "titwank", "tosser", "turd", "tw4t", "twat", "twathead", "twatty", "twunt", "twunter", "v14gra", "v1gra", "vagina", "viagra", "vulva", "w00se", "wank", "wanker", "wanky", "whoar", "whore", "willies", "willy", "xrated", "xxx"]
    
    static let RsvdUsernameSeqs = ["fuck", "shit"]
    
    static let RsvdUsernameSuffix = [".js", ".json", ".css", ".html", ".htm", ".xml", ".jpg", ".jpeg", ".h264", ".png", ".gif", ".bmp", ".ico", ".tif", ".tiff", ".woff", "swift", ".m", ".h", ".c", ".mov", ".avi", ".log", ".txt", ".doc", ".xls", ".ppt", ".pdf", ".mp3", ".wav", ".wma", ".pkg", ".rpm", ".rar", ".tar", ".gz", ".zip", ".bin", ".dmg", ".iso", ".csv", ".dat", ".sql", ".php", ".py", ".bat", ".cgi", ".pl", ".com", ".net", ".co", ".org", ".exe", ".jar", ".ttf", ".ai", ".ps", ".psd", ".cgi", ".js", ".rss", ".xhtml", ".asp", ".aspx", ".key", ".pptx", ".class", ".cpp", ".sh", ".vb", ".docx", ".xlsx", ".cfg", ".dll", ".sys", ".tmp", ".msi", ".ini", ".3g2", ".3gp", ".m4v", ".mkv", ".mpg", ".mpeg", ".wmv", ".rtf"]
    
    static let RsvdUsernameCharRegex = "[^0-9a-zA-ZÀ-ÿ\\-_=|:.]"
    static let AllowedUsernameSymbols = "-_=|:."
    
    static let RsvdPasswordSeqs = ["abc", "123", "tastry", "password"]
  }
}
