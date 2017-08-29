//
//  AppDelegate.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-19.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit
import Parse

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    var error: Error?
    
    // Create S3 Manager singleton
    FoodieFile.manager = FoodieFile()
    
    // Create Prefetch Manager singleton
    FoodiePrefetch.global = FoodiePrefetch()
    
    // Initialize Location Watch manager
    LocationWatch.global = LocationWatch()
    
    // Initialize Parse
    Parse.enableLocalDatastore()
    
    let configuration = ParseClientConfiguration {
      $0.applicationId = "bcq2IsV9NHVi8vwIQZXOr5Qzyqoj0ts1sgt7hNlw"
      $0.clientKey = "yE4Bbq5vIv03oNNrhyAy5eu9AWUIIh1mj4LFmt81"
      $0.server = "https://parseapi.back4app.com"
      $0.isLocalDatastoreEnabled = true
    }
    Parse.initialize(with: configuration)
    
    // For Parse Subclassing
    configureParse()
    
    // Initialize Das Quadrat
    FoodieGlobal.foursquareInitialize()
    FoodieCategory.getFromFoursquare(withBlock: nil)  // Let the fetch happen in the background
    
    // TODO: - Any Startup Test we want to do that we should use to block Startup?
    error = nil
    
    // Launch Root View Controller
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
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
    // check to see if there is any draft journal
    let query = FoodieJournal.query()!
    query.fromPin(withName: "workingJournal")
    query.getFirstObjectInBackground() { (object, error) in
      
      if let error = error {
        DebugPrint.error("Fetching Journal from Local Datastore resulted in error - \(error.localizedDescription)")
        return
      }
      
      guard let journal = object as? FoodieJournal else {
        DebugPrint.error("Retrieve pinned Journal from Local Datastore is nil or not a FoodieJournal")
        return
      }
      
      journal.retrieveRecursive(forceAnyways: false) { error in
        journal.foodieObject.markModified()
        FoodieJournal.setJournal(journal: journal)
      }
    }
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  // For Parse Subclassing
  func configureParse() {
    
    // FoodieObject is an Abstract! Don't Register!!
    FoodieUser.registerSubclass()
    FoodieJournal.registerSubclass()
    FoodieVenue.registerSubclass()
    FoodieCategory.registerSubclass()
    FoodieMoment.registerSubclass()
    FoodieMarkup.registerSubclass()
    FoodieHistory.registerSubclass()
  }
}

