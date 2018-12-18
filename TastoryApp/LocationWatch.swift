//
//  LocationWatch.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-08-23.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

class LocationWatch: NSObject {
  
  // MARK: - Types & Enumerations
  
  typealias LocationErrorBlock = (CLLocation?, Error?) -> Void
  
  enum WatchState {
    case started
    case paused
    case stopped
  }
  
  
  
  // MARK: Error Types
  
  enum ErrorCode: LocalizedError {
    
    case managerFailWithNoCLError
    case managerFailUndeterminedLocation
    case managerFailDenied
    case managerFailUnknownError
    
    var errorDescription: String? {
      switch self {
      case .managerFailWithNoCLError:
        return NSLocalizedString("Location Manager failed no CLError", comment: "Error description for an exception error code")
      case .managerFailUndeterminedLocation:
        return NSLocalizedString("Location Manager failed. Unable to determine location Location", comment: "Error description for an exception error code")
      case .managerFailDenied:
        return NSLocalizedString("Location Services permission denied. Please use the map to determine search parameters", comment: "Error description for an exception error code")
      case .managerFailUnknownError:
        return NSLocalizedString("Location Manager failed with undetermined error", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Classes & Structs
  
  class Context: ThreadSafeDLL.Node {
    
    // MARK: - Private Instance Variables
    fileprivate var callback: LocationErrorBlock!
    fileprivate var continuous: Bool!
    fileprivate var state: WatchState!
    
    // MARK: - Public Instance Variables
    var isStarted: Bool { return state == .started }
    var isPaused: Bool { return state == .paused }
    var isStopped: Bool { return state == .stopped }
    
    // MARK: - Public Instance Functions
    func pause() { LocationWatch.global.pause(self) }
    
    func resume() { LocationWatch.global.resume(self) }
    
    func stop() { LocationWatch.global.stop(self) }
  }
  
  
  
  // MARK: - Private Constants
  
  struct Constants {
    static let defaultDistanceFilter = CLLocationDistance(30.0)  // meters, for LocationManager
  }
  
  
  
  // MARK: - Read Only Static Variables
  
  private(set) static var global: LocationWatch!
  
  
  
  // MARK: - Private Instance Variables
  
  private var manager = CLLocationManager()
  private var watcherDLL = ThreadSafeDLL()
  private var locationUpdating = false
  private var errorMode = false
  private var currentLocation: CLLocation?
  

  
  // MARK: - Public Static Functions
  
  static func initializeGlobal() {
    if global == nil {
      global = LocationWatch()
    } else {
      CCLog.warning("Attempt to initialize Global more than once detected")
    }
  }
  
  
  static func checkAndRequestAuthorizations() -> UIAlertController? {
    
    if !CLLocationManager.locationServicesEnabled() {
      return AlertDialog.createUrlDialog(title: "Location Services Disabled",
                                         message: "For best experience, please go to Settings > Privacy > Location Services and enable 'Location Services'",
                                         url: "App-Prefs:root=Privacy&path=LOCATION")
    }
    
    let locationAuthorizationStatus = CLLocationManager.authorizationStatus()
    
    switch locationAuthorizationStatus {
      
    case .notDetermined:
      LocationWatch.global.manager.requestWhenInUseAuthorization()
      break
      
    case .denied:
      fallthrough
    case .restricted:
      let appName = Bundle.main.displayName ?? "Tastory"
      return AlertDialog.createUrlDialog(title: "Location Services Denied",
                                         message: "For best experience, please go to Settings > Privacy > Location Services and toggle to 'While Using' for \(appName)",
                                         url: UIApplication.openSettingsURLString)
      
    case .authorizedAlways:
      fallthrough
    case .authorizedWhenInUse:
      // this is for people who have already allowed location services but not push notification
      requestPushNotification()
      break
      
    }
    
    return nil
  }
  
  
  
  // MARK: - Private Instance Functions
  
  private func notifyWatchers (withLocation location: CLLocation? = nil, withError error: Error? = nil) {
    if let watcherArray = watcherDLL.convertToArray() as? [Context] {
      for watcher in watcherArray {
        if watcher.isStarted {
          watcher.callback(location, error)
          if !watcher.continuous && (location != nil) { watcher.stop() }
        }
      }
    }
  }

  private static func requestPushNotification() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      (granted, error) in

      if let error = error {
        CCLog.warning("An error occured when trying register push notification \(error.localizedDescription)")
      } else {
        guard granted else { return }
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
          print("Notification settings: \(settings)")
          guard settings.authorizationStatus == .authorized else { return }
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
      }
    }
  }

  // MARK: - Public Instance Functions
  
  override init() {
    super.init()
    
    // Setup Location Manager
    manager.delegate = self
    manager.requestWhenInUseAuthorization()
    manager.pausesLocationUpdatesAutomatically = false
    manager.allowsBackgroundLocationUpdates = false
    manager.distanceFilter = Constants.defaultDistanceFilter
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.activityType = CLActivityType.fitness  // Fitness Type includes Walking
    manager.disallowDeferredLocationUpdates()
  }

  
  func get(withBlock callback: @escaping LocationErrorBlock) {
    
    if let location = currentLocation {
      DispatchQueue.global(qos: .userInitiated).async { callback(location, nil) }
    } else {
      let watcher = Context()
      watcher.callback = callback
      watcher.continuous = false
      watcher.state = .started
      
      watcherDLL.add(toTail: watcher)
      manager.startUpdatingLocation()
    }
  }
  
  
  func start(butPaused: Bool = false, withBlock callback: @escaping LocationErrorBlock) -> Context {

    let watcher = Context()
    watcher.callback = callback
    watcher.continuous = true
    
    if butPaused == true {
      watcher.state = .paused
    } else {
      watcher.state = .started
    }
    watcherDLL.add(toTail: watcher)
    
    if let location = currentLocation, !butPaused {
      DispatchQueue.global(qos: .utility).async { watcher.callback(location, nil) }
    }
    manager.startUpdatingLocation()
    
    return watcher
  }

  
  func pause(_ watcher: Context) {
    watcher.state = .paused
  }
  
  
  func resume(_ watcher: Context) {

    watcher.state = .started
    if let location = currentLocation {
      DispatchQueue.global(qos: .utility).async { watcher.callback(location, nil) }
    }
    manager.startUpdatingLocation()
  }
  
  func stop(_ watcher: Context) {

    watcher.state = .stopped
    watcherDLL.remove(watcher)
    
    if watcherDLL.isEmpty {
      manager.stopUpdatingLocation()
      currentLocation = nil  // Make sure Current Location won't get out of date
    }
  }
}



extension LocationWatch: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    errorMode = false  // Clear Error mode upon a Successful Location Update
    if !locations.isEmpty {
      currentLocation = locations[0]
      notifyWatchers(withLocation: locations[0])
    }
  }
  
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

    guard !errorMode else {
      return  // We are already in Error Mode, which mean a Notification was already sent. Don't send more.
    }
    errorMode = true
    
    guard let errorCode = error as? CLError else {
      notifyWatchers(withError: ErrorCode.managerFailWithNoCLError)
      CCLog.assert("Not getting CLError upon a Location Manager Error")
      return
    }
    
    CCLog.warning("CLError.code = \(errorCode.code.rawValue)")
    
    switch errorCode.code {
      
    case .locationUnknown:
      notifyWatchers(withError: ErrorCode.managerFailUndeterminedLocation)
      CCLog.debug("Unable to determine Location")
      
    case .denied:
      // User denied authorization
      manager.stopUpdatingLocation()
      currentLocation = nil
      notifyWatchers(withError: ErrorCode.managerFailDenied)
      CCLog.debug("Location Services Denied")
      
    default:
      notifyWatchers(withError: ErrorCode.managerFailUnknownError)
      CCLog.assert("Unrecognized fallthrough, error.localizedDescription = \(error.localizedDescription)")
    }
  }
  
  func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    // TODO
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

    switch status {
    case .authorizedAlways:
      fallthrough
    case .authorizedWhenInUse:
      // Request for push notification
      // always show the request dialog right after requesting for location access 
      LocationWatch.requestPushNotification()

      break

    default:
      break
    }
  }
}
