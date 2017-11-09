//
//  AppDelegate.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-19.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  

  // MARK: - Private Instance Functions
  
  private func topViewController(for application: UIApplication) -> UIViewController? {
    if var topController = application.keyWindow?.rootViewController {
      while let presentedViewController = topController.presentedViewController {
        topController = presentedViewController
      }
      return topController
    }
    return nil
  }
  
  
  // MARK: - Public Instance Functions
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    var error: Error?
    
    // Initialize Crash, Error & Log Reporting
    CCLog.initializeLogging()
    CCLog.initializeReporting()
    
    // Initialize Foodie Model
    FoodieGlobal.initialize()

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
    if let topOverlayViewController = topViewController(for: application) as? OverlayViewController {
      topOverlayViewController.topViewWillResignActive()
    } else if let topMapNavController = topViewController(for: application) as? MapNavController {
      topMapNavController.topViewWillResignActive()
    }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    if let topOverlayViewController = topViewController(for: application) as? OverlayViewController {
      topOverlayViewController.topViewDidEnterBackground()
    } else if let topMapNavController = topViewController(for: application) as? MapNavController {
      topMapNavController.topViewDidEnterBackground()
    }
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    if let topOverlayViewController = topViewController(for: application) as? OverlayViewController {
      topOverlayViewController.topViewWillEnterForeground()
    } else if let topMapNavController = topViewController(for: application) as? MapNavController {
      topMapNavController.topViewWillEnterForeground()
    }
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if let topOverlayViewController = topViewController(for: application) as? OverlayViewController {
      topOverlayViewController.topViewDidBecomeActive()
    } else if let topMapNavController = topViewController(for: application) as? MapNavController {
      topMapNavController.topViewDidBecomeActive()
    }
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
}

