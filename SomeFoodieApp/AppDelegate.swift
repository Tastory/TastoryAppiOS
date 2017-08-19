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
    
    // Create S3 Manager singleton
    FoodieFile.manager = FoodieFile()
    
    // Create Prefetch Manager singleton
    FoodiePrefetch.global = FoodiePrefetch()
    
    // Initialize Parse.
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
    let query = PFQuery(className: FoodieJournal.parseClassName())
    query.fromPin(withName: "workingJournal")

    query.getFirstObjectInBackground(block: { (fetchedObject, error) in
      if(fetchedObject == nil)
      {
        DebugPrint.verbose("Failed to retrieve workingJournal from local data store")
        return
      }

      let currentJournal = fetchedObject as! FoodieJournal
      do {
        //try currentJournal.fetchIfNeeded()
        currentJournal.thumbnailObj = FoodieMedia(withState: .savedToLocal, fileName: currentJournal.thumbnailFileName!, type: FoodieMediaType.photo)

        if let moments = currentJournal.moments {
          FoodieMoment.queryFromPin(withName: "workingJournal", withBlock: {(fetchedMoments,error )-> Void in

            if error != nil
            {
              DebugPrint.verbose("Error fetching moments from pinned local store")
            }

            currentJournal.moments?.removeAll()
            //TODO possible that there is zero moment
            for moment in (fetchedMoments!) {

              let foodieMoment = moment as! FoodieMoment

              foodieMoment.mediaObj = FoodieMedia(withState: .savedToLocal, fileName: foodieMoment.mediaFileName!, type:  FoodieMediaType(rawValue:  foodieMoment.mediaType!)!)
              //TODO make sure the file exists
              foodieMoment.thumbnailObj = FoodieMedia(withState: .savedToLocal, fileName: foodieMoment.thumbnailFileName!, type: FoodieMediaType.photo)
              currentJournal.moments?.append(foodieMoment)
            }
            currentJournal.foodieObject.markModified()
            FoodieJournal.setJournal(journal: currentJournal)
          })
        }
      } catch {
        DebugPrint.verbose("Failed to retrieve workingJournal from local data store")
      }
    })
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  // For Parse Subclassing
  func configureParse() {
    
    // FoodieObject is an Abstract! Don't Register!!
    
    FoodieUser.registerSubclass()
    FoodieJournal.registerSubclass()
    FoodieEatery.registerSubclass()
    FoodieCategory.registerSubclass()
    FoodieMoment.registerSubclass()
    FoodieMarkup.registerSubclass()
    FoodieHistory.registerSubclass()
  }
}

