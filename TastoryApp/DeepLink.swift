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
  var showConfirmDiscard: Bool = false
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

        // reset root disaplay VC only when logged in
        if displayedVC is MarkupViewController || displayedVC is StoryEntryViewController {
          AlertDialog.presentConfirm(from: displayedVC, title: "Discard", message: "Your changes have not been saved. Are you sure you want to exit?") { (action) in
            rootVC.dismiss(animated: false)
          }
        } else {
           rootVC.dismiss(animated: false)
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

  func createDeepLink(userId: String, story: FoodieStory? = nil, block callback: @escaping (String?, Error?)->Void ) {

    let buo = BranchUniversalObject(canonicalIdentifier: "content")

    var uri = DeepLink.Constants.UserKey + "/" + userId

    if let story = story {

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

      uri = uri + "/" + DeepLink.Constants.StoryKey + "/" + objectId
      buo.title = story.title
      buo.imageUrl = FoodieFileObject.getS3URL(for: thumbnailName).absoluteString
    }

    buo.contentMetadata.customMetadata[DeepLink.Constants.URI] = uri

    let lp: BranchLinkProperties = BranchLinkProperties()
    lp.channel = "app"
    lp.feature = "profile_sharing"

    buo.getShortUrl(with: lp) { (url, error) in
      callback(url,error)
    }
  }

  static func clearDeepLinkInfo() {
    DeepLink.global.deepLinkUserId = nil
    DeepLink.global.deepLinkStoryId = nil
  }
}
