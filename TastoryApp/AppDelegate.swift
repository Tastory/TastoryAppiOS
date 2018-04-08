
//
//  AppDelegate.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-03-19.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AsyncDisplayKit
import Parse
import FBSDKCoreKit
import Firebase
import UserNotifications

// import COSTouchVisualizer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate /*, COSTouchVisualizerWindowDelegate*/ {

  var window: UIWindow?

  // MARK: - Private Instance Functions
  
  private func printFonts() {
    let fontFamilyNames = UIFont.familyNames
    
    for familyName in fontFamilyNames {
      print("------------------------------")
      print("Font Family Name = [\(familyName)]")
      let names = UIFont.fontNames(forFamilyName: familyName)
      print("Font Names = [\(names)]")
    }
  }
  
  
  // MARK: - Public Instance Functions

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    var error: Error?
    
    // Print Fonts if needed
//    printFonts()
    
    // Setup Window
//    let cosTouchWindow = COSTouchVisualizerWindow(frame: UIScreen.main.bounds)
//    cosTouchWindow.backgroundColor = UIColor.white
//    cosTouchWindow.fillColor = UIColor.white
//    cosTouchWindow.strokeColor = UIColor.white
//    cosTouchWindow.touchAlpha = 0.2;
//    cosTouchWindow.rippleFillColor = UIColor.white
//    cosTouchWindow.rippleStrokeColor = UIColor.white
//    cosTouchWindow.touchAlpha = 0.1;
//    cosTouchWindow.touchVisualizerWindowDelegate = self
//    window = cosTouchWindow

    // Initialize Crash, Error & Log Reporting
    CCLog.initializeLogging()
    CCLog.initializeReporting()
    
    ASDisableLogging()
    // ASDisplayNode.shouldShowRangeDebugOverlay = true
    
    // Initialize Foodie Model
    FoodieGlobal.initialize()
    PFFacebookUtils.initializeFacebook(applicationLaunchOptions: launchOptions)
    DeepLink.global = DeepLink(launchOptions: launchOptions)
    FirebaseApp.configure()
    
    
    // Initialize the Global Activity Spinner
    ActivitySpinner.globalInit()
    
    // TODO: - Any Startup Test we want to do that we should use to block Startup?
    error = nil
    
    // Launch Root View Controller
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "RootViewController") as? RootViewController else {
      CCLog.fatal("ViewController initiated not of RootViewController Class!!")
    }
    viewController.startupError = error
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = viewController
    window?.makeKeyAndVisible()
    updateAppLastUsed()

    UNUserNotificationCenter.current().getNotificationSettings { (settings) in
      if settings.authorizationStatus == .authorized {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
    return true
  }

  // Respond to Universal Links
  func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
    DeepLink.global.processUniversalLink(userActivity)
    return true
  }

  func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
    return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
  }
  
  func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
    return true
  }
  
  func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
    return false
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    if let topOverlayViewController = OverlayViewController.getTopViewController() as? OverlayViewController {
      topOverlayViewController.topViewWillResignActive()
    } else if let topMapNavController = OverlayViewController.getTopViewController() as? MapNavController {
      topMapNavController.topViewWillResignActive()
    }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    if let topOverlayViewController = OverlayViewController.getTopViewController() as? OverlayViewController {
      topOverlayViewController.topViewDidEnterBackground()
    } else if let topMapNavController = OverlayViewController.getTopViewController() as? MapNavController {
      topMapNavController.topViewDidEnterBackground()
    }
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    if let topOverlayViewController = OverlayViewController.getTopViewController()  as? OverlayViewController {
      topOverlayViewController.topViewWillEnterForeground()
    } else if let topMapNavController = OverlayViewController.getTopViewController() as? MapNavController {
      topMapNavController.topViewWillEnterForeground()
    }
    DeepLink.global.isAppResume = true
    updateAppLastUsed()
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if let topOverlayViewController = OverlayViewController.getTopViewController() as? OverlayViewController {
      topOverlayViewController.topViewDidBecomeActive()
    } else if let topMapNavController = OverlayViewController.getTopViewController() as? MapNavController {
      topMapNavController.topViewDidBecomeActive()
    }
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data -> String in
      return String(format: "%02.2hhx", data)
    }

    let token = tokenParts.joined()
    CCLog.verbose("Device Token: \(token)")
    guard let installation = PFInstallation.current() else  {
      CCLog.fatal("Cannot get an instance of PFInstallation")
    }
    installation.setDeviceTokenFrom(deviceToken)

    if let userID = FoodieUser.current()?.objectId {
      installation.setObject(userID, forKey: "userID")
    }

    installation.saveInBackground()
  }

  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    CCLog.warning("Failed to register for Push Notification: \(error.localizedDescription)")
  }

  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]){
    if application.applicationState != .active {
      DeepLink.global.handlePushNotification(userInfo)
    }
  }

  // MARK: - Private Instance Functions
  private func updateAppLastUsed() {
    guard let installation = PFInstallation.current() else  {
      CCLog.fatal("Cannot get an instance of PFInstallation")
    }

    if installation.objectId != nil {
      //installation.fetchIfNeeded()

      installation.fetchInBackground() { (_ , error) in

        let lastUsed: Double = Date().timeIntervalSince1970
        installation.setValue(lastUsed, forKey: "lastUsedApp")

        if let currentUser = FoodieUser.current() {

          if let userID = currentUser.objectId {
            installation.setObject(userID, forKey: "userID")
          }

          if let userName = currentUser.username {
            installation.setValue(userName, forKey: "userName")
          }
        }

        installation.badge = 0
        installation.saveInBackground(){ (success, error) -> Void in
          if let error = error {
             CCLog.assert("Failed to update PFInstallation object with error: \(error.localizedDescription)")
          } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
          }
        }
      }
    }
  }
 

  // MARK: - COSTouchVisualizerWindowDelegate
//  func touchVisualizerWindowShouldShowFingertip(_ window: COSTouchVisualizerWindow!) -> Bool {
//    return true
//  }
//
//  func touchVisualizerWindowShouldAlwaysShowFingertip(_ window: COSTouchVisualizerWindow!) -> Bool {
//    return false
//  }
}

