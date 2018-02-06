//
//  DeepLink.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-01.
//  Copyright © 2018 Tastry. All rights reserved.
//

import Foundation
import Branch

class DeepLink {

  struct Constants {
    static let StoryKey = "Story"
    static let UserKey = "User"
    static let URI = "URI"
  }

  enum ErrorCode: LocalizedError {

    case missingStoryId
    case missingThumbnailFileName

    var errorDescription: String? {
      switch self {
      case .missingStoryId:
        return NSLocalizedString("The story is missing the objectId", comment: "Error description for an exception error code")
      case .missingThumbnailFileName:
        return NSLocalizedString("The thumbnail is missing the fileName", comment: "Error description for an exception error code")
      }
    }
  }

  // MARK: - Private Instance Variables
  private var instance: Branch? = nil

  // Mark: - Public Static Variables
  static var global: DeepLink!

  // MARK: - Public Instance Variables
  var isAppResume: Bool = false
  var deepLinkUserId: String?
  var deepLinkStoryId: String?

  init(launchOptions: [UIApplicationLaunchOptionsKey: Any]?) {

    if instance == nil {
      //Branch.io initialization
      #if DEBUG
        //TODO remove this for production purporses  use the test mode first
        Branch.setUseTestBranchKey(true)
      #endif

      instance =  Branch.getInstance()

      guard let currentInstance = instance else {
        CCLog.assert("Failed to get an initialized instance of Branch")
        return
      }

      currentInstance.initSession(launchOptions: launchOptions)  {(params, error) in

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let window = appDelegate.window, let rootVC = window.rootViewController else {
          CCLog.fatal("Cannot get AppDelegate.window.rootViewController!!!!")
        }

        var displayedVC = rootVC

        if let resumeTopVC = OverlayViewController.getTopViewController(){
          displayedVC = resumeTopVC
        }

        guard let params = params else {
          AlertDialog.standardPresent(from: displayedVC, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.assert("DeepLink Params is nil")
          }
          return
        }

        guard let uri = params[Constants.URI] as? String else {
          CCLog.warning("No deep link URI found")
          return
        }

        guard let url = URL(string: uri) else {
          AlertDialog.standardPresent(from: displayedVC, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.assert("Unable to create url from uri")
          }
          return
        }

        // parse the content URI
        // a path /user/<username> breaks down into
        // [ "user", "username" ] always in key and value pair form
        let paths:[String] = url.pathComponents

        var i = 0
        while(i < paths.count) {
          if (i+1 < paths.count) {
            switch(paths[i]) {
            case Constants.UserKey:
              DeepLink.global.deepLinkUserId = paths[i+1]
              break
            case Constants.StoryKey:
              DeepLink.global.deepLinkStoryId = paths[i+1]
              break
            default:
              AlertDialog.standardPresent(from: displayedVC, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.assert("Unknown parameter is used in the URI")
                DeepLink.clearDeepLinkInfo()
              }
              return
              break
            }
          } else {
            AlertDialog.standardPresent(from: displayedVC, title: .genericInternalError, message: .inconsistencyFatal) { _ in
              CCLog.assert("URI is malformed. Exepected key and followed by value")
              DeepLink.clearDeepLinkInfo()
            }
            return
          }
          i = i + 2
        }

        // ask for confirmation before reseting VC
        if displayedVC is MarkupViewController || displayedVC is StoryEntryViewController {
          AlertDialog.presentConfirm(from: displayedVC, title: "Discard", message: "Your changes have not been saved. Are you sure you want to exit?") { (action) in
            rootVC.dismiss(animated: false)
          }
        } else {
          // check to see if other VC is on top of the discovery VC
          if displayedVC.childViewControllers.count > 1 {
             rootVC.dismiss(animated: false)
          }
          if displayedVC.childViewControllers.count == 1,  self.isAppResume {
            self.isAppResume = false
            CCLog.verbose("victor \(self.isAppResume)")
            if let discoverVC = displayedVC.childViewControllers[0] as? DiscoverViewController {
              discoverVC.displayDeepLinkContent()
            }
          }
        }
      }
    }
  }

  func processUniversalLink(_ userActivity: NSUserActivity) {
    guard let currentInstance = instance else {
      CCLog.warning("Failed to get an initialized instance of Branch")
      return
    }

    currentInstance.continue(userActivity)
  }

  func createProfileDeepLink(user: FoodieUser, block callback: @escaping (String?, Error?)->Void ) {
    let buo = BranchUniversalObject(canonicalIdentifier: "content")

    guard let userId = user.objectId else {
      CCLog.assert("the user id is missing from FoodieUser")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    guard let userName = user.username else {
      CCLog.assert("the user name is missing from the author")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    var title = userName

    //if let name = user.fullName {

      

    if let bio = user.biography {
      title = title + ": " + bio
    }
    buo.title = title
    //buo.contentDescription = user.biography
    if let mediaName = user.profileMediaFileName {
      buo.imageUrl = FoodieFileObject.getS3URL(for: mediaName).absoluteString
    }
    // TODO add default url image when user is missing their profile pic

    buo.contentMetadata.customMetadata[DeepLink.Constants.URI] = DeepLink.Constants.UserKey + "/" + userId

    let lp: BranchLinkProperties = BranchLinkProperties()
    lp.channel = "app"
    lp.feature = "profile_sharing"

    buo.getShortUrl(with: lp) { (url, error) in
      callback(url,error)
    }
  }

  func createStoryDeepLink(story: FoodieStory, block callback: @escaping (String?, Error?)->Void ) {

    let buo = BranchUniversalObject(canonicalIdentifier: "content")

    guard let user = story.author else {
      CCLog.assert("The author is missing from the foodie story")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    guard let userId = user.objectId else {
      CCLog.assert("the user id is missing from FoodieUser")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    guard let userName = user.username else {
      CCLog.assert("the user name is missing from the author")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    guard let objectId = story.objectId else {
      CCLog.assert("the story is missing an object id")
      callback(nil, ErrorCode.missingStoryId)
      return
    }

    guard let thumbnailName = story.thumbnailFileName else {
      CCLog.assert("the story is missing a thumbnail file name")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    buo.title = story.title
    buo.contentDescription = "by " + userName
    buo.imageUrl = FoodieFileObject.getS3URL(for: thumbnailName).absoluteString

    buo.contentMetadata.customMetadata[DeepLink.Constants.URI] = DeepLink.Constants.UserKey + "/" + userId + "/" + DeepLink.Constants.StoryKey + "/" + objectId

    let lp: BranchLinkProperties = BranchLinkProperties()
    lp.channel = "app"
    lp.feature = "story_sharing"

    buo.getShortUrl(with: lp) { (url, error) in
      callback(url,error)
    }
  }

  static func clearDeepLinkInfo() {
    DeepLink.global.deepLinkUserId = nil
    DeepLink.global.deepLinkStoryId = nil
  }
}
