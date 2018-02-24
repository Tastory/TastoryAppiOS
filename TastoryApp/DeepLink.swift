//
//  DeepLink.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-01.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import Foundation
import Branch

class DeepLink {

  struct Constants {
    static let StoryKey = "Story"
    static let VenueKey = "Venue"
    static let UserKey = "User"
    static let URI = "URI"
  }

  enum ErrorCode: LocalizedError {

    case missingId
    case missingThumbnailFileName

    var errorDescription: String? {
      switch self {
      case .missingId:
        return NSLocalizedString("The content is missing an identifier", comment: "Error description for an exception error code")
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
  var deepLinkVenueId: String?

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
            case Constants.VenueKey:
              DeepLink.global.deepLinkVenueId = paths[i+1]
              break
            default:
              AlertDialog.standardPresent(from: displayedVC, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.assert("Unknown parameter is used in the URI")
                DeepLink.clearDeepLinkInfo()
              }
              return
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
          // Assumption: the displayed VC is a mapNav controller and its childViewController at index 0 is a DiscoveryVC
          // displayedVC could be a loginViewController if user clicked on deeplink and not logged in
          if let mapNavVC = displayedVC as? MapNavController {
            // check to see if other VC is on top of the MapNavController
            if mapNavVC.childViewControllers.count > 1 {
              rootVC.dismiss(animated: false)
            } else if mapNavVC.childViewControllers.count == 1 {
              if self.isAppResume {
                self.isAppResume = false
                if let discoverVC = displayedVC.childViewControllers[0] as? DiscoverViewController {
                  discoverVC.displayDeepLinkContent()
                }
              }
            } else {
              CCLog.fatal("Expected childViewController to contain DiscoveryVC")
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
      callback(nil, ErrorCode.missingId)
      return
    }

    var title = ""
    var description = "See tasty stories curated by "

    if let fullName = user.fullName {
      title += fullName
      description += fullName
      
    }

    if let username = user.username {
      let nameStr = " (@" + username + ")"
      title += nameStr
      description += nameStr
    }

    title += " on Tastory"

    buo.title = title
    buo.contentDescription = description
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

  func createVenueDeepLink(venue: FoodieVenue, thumbnailURL: String, block callback: @escaping (String?, Error?)->Void ) {
    let buo = BranchUniversalObject(canonicalIdentifier: "content")

    guard let venueId = venue.objectId else {
      CCLog.assert("the venue id is missing from Foodievenue")
      callback(nil, ErrorCode.missingId)
      return
    }

    var title = ""
    var description = "See tasty stories of "

    if let venueName = venue.name {
      title += venueName
      description += venueName

    }

    buo.title = title
    buo.contentDescription = description

    // TODO add default url image when user is missing their profile pic
    buo.contentMetadata.customMetadata[DeepLink.Constants.URI] = DeepLink.Constants.VenueKey + "/" + venueId
    buo.imageUrl = thumbnailURL

    let lp: BranchLinkProperties = BranchLinkProperties()
    lp.channel = "app"
    lp.feature = "venue_sharing"

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

    guard let objectId = story.objectId else {
      CCLog.assert("the story is missing an object id")
      callback(nil, ErrorCode.missingId)
      return
    }

    guard let thumbnailName = story.thumbnailFileName else {
      CCLog.assert("the story is missing a thumbnail file name")
      callback(nil, ErrorCode.missingThumbnailFileName)
      return
    }

    var title = ""
    var description = ""

    if let storyTitle = story.title {
      title = storyTitle
    }

    title += " by"

    if let fullName = user.fullName {
      title += " " + fullName
      description += fullName
    }

    if let username = user.username {
      let nameStr = " (@" + username + ")"
      title += nameStr
      description += nameStr
    }

    title += " on Tastory"

    buo.title = title
    buo.contentDescription = description + " | tasty story on Tastory"
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
    DeepLink.global.deepLinkVenueId = nil
  }
}
