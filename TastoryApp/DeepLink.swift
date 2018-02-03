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

  // MARK: - Private Instance Variables
  private var instance: Branch? = nil

  // MARK: - Public Instance Variables
  static var deepLinkUserName: String?
  static var deepLinkStoryId: String?
  var showConfirmDiscard: Bool = false

  init(launchOptions: [UIApplicationLaunchOptionsKey: Any]?) {

    if instance == nil {
      //Branch.io initialization
      #if DEBUG
        //TODO remove this for production purporses  use the test mode first
        Branch.setUseTestBranchKey(true)
      #endif

      instance =  Branch.getInstance()

      guard let currentInstance = instance else {
        CCLog.warning("Failed to get an initialized instance of Branch")
        return
      }

      currentInstance.initSession(launchOptions: launchOptions)  {(params, error) in
        if error != nil {
          CCLog.warning("A DeepLink error occurred when getting params: \(String(describing: error))")
          return
        }

        guard let params = params else {
          CCLog.warning("DeepLink Params is nil")
          return
        }

        guard let uri = params[Constants.URI] as? String else {
          CCLog.warning("URI is missing from Deep Link params: \(params)")
          return
        }

        guard let url = URL(string: uri) else {
          CCLog.fatal("unable to create url from uri")
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
              DeepLink.deepLinkUserName = paths[i+1]
              break
            case Constants.StoryKey:
              DeepLink.deepLinkStoryId = paths[i+1]
              break
            default:
              break
            }
          }
          i = i + 2
        }

        // reset root disaplay VC only when logged in
        if let user = FoodieUser.current(), user.isAuthenticated {

          guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let window = appDelegate.window, let rootVC = window.rootViewController else {
              CCLog.fatal("Cannot get AppDelegate.window.rootViewController!!!!")
          }

          if let resumeTopVC = appDelegate.resumeTopVC, resumeTopVC is MarkupViewController {
            AlertDialog.presentConfirm(from: resumeTopVC, title: "Discard", message: "Changes to your markups have not been saved. Are you sure you want to exit?") { (action) in
              rootVC.dismiss(animated: false)
            }
            appDelegate.resumeTopVC = nil
          } else {
             rootVC.dismiss(animated: false)
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

  func createDeepLink(username: String, storyId: String? = nil, block callback: @escaping (String?, Error?)->Void ) {
    let buo = BranchUniversalObject(canonicalIdentifier: "content")

    var uri = DeepLink.Constants.UserKey + "/" + username

    if storyId != nil {
      uri = uri + "/" + DeepLink.Constants.StoryKey + "/" + storyId!
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
    DeepLink.deepLinkUserName = nil
    DeepLink.deepLinkStoryId = nil
  }
}
