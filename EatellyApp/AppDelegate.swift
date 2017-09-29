//
//  AppDelegate.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-19.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    var error: Error?
    
    // Initialize Crash, Error & Log Reporting
    CCLog.initializeLogging()
    CCLog.initializeReporting()
    
    // Enable Automatic User
    FoodieUser.enableAutoGuestUser()
    
    // Initialize FoodieObject Database
    FoodieObject.initialize()
    
    // Create S3 Manager singleton
    FoodieFile.manager = FoodieFile()
    
    // Create Prefetch Manager singleton
    FoodiePrefetch.global = FoodiePrefetch()
    
    // Initialize Das Quadrat
    FoodieGlobal.foursquareInitialize()
    FoodieCategory.getFromFoursquare(withBlock: nil)  // Let the fetch happen in the background
    
    // Initialize Location Watch manager
    LocationWatch.global = LocationWatch()

    // TODO: - Any Startup Test we want to do that we should use to block Startup?
    error = nil
    
    // Launch Root View Controller
    let storyboard = UIStoryboard(name: "LogInSignUp", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "RootViewController") as! RootViewController
    viewController.startupError = error
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = viewController
    window?.makeKeyAndVisible()
    return true
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
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
}

