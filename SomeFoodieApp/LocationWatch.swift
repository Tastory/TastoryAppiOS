//
//  LocationWatch.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-23.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import CoreLocation


class LocationWatch: NSObject {
  
  // MARK: - Types & Enumerations
  typealias LocationErrorBlock = (CLLocation?, Error?) -> Void
  
  enum WatchState {
    case started
    case paused
    case stopped
  }
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case managerFailWithNoCLError
    case managerFailUndeterminedLocation
    case managerFailDenied
    case managerFailUnknownError
    
    var errorDescription: String? {
      switch self {
      case .managerFailWithNoCLError:
        return NSLocalizedString("Location Manager Failed no CLError", comment: "Error description for an exception error code")
      case .managerFailUndeterminedLocation:
        return NSLocalizedString("Location Manager Failed Undetermined Location", comment: "Error description for an exception error code")
      case .managerFailDenied:
        return NSLocalizedString("Location Manager Failed Permission Denied", comment: "Error description for an exception error code")
      case .managerFailUnknownError:
        return NSLocalizedString("Location Manager Failed Unknown Error", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
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
  
  
  // MARK: - Public Static Variables
  static var global: LocationWatch!
  
  
  // MARK: - Private Instance Variables
  fileprivate var manager = CLLocationManager()
  fileprivate var watcherDLL = ThreadSafeDLL()
  fileprivate var locationUpdating = false
  fileprivate var errorMode = false
  fileprivate var currentLocation: CLLocation?
  
  
  // MARK: - Private Instance Functions
  fileprivate func notifyWatchers (withLocation location: CLLocation? = nil, withError error: Error? = nil) {
    if let watcherArray = watcherDLL.convertToArray() as? [Context] {
      for watcher in watcherArray {
        if watcher.isStarted {
          watcher.callback(location, error)
          if !watcher.continuous && (location != nil) { watcher.stop() }
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
  
  
  // MARK: - Public Static Functions
  func get(withBlock callback: @escaping LocationErrorBlock) {
    let watcher = Context()
    watcher.callback = callback
    watcher.continuous = false
    watcher.state = .started
    watcherDLL.add(toTail: watcher)
    
    if let location = currentLocation {
      DispatchQueue.global(qos: .userInitiated).async { watcher.callback(location, nil) }
    }
    manager.startUpdatingLocation()
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
      DebugPrint.assert("Not getting CLError upon a Location Manager Error")
      return
    }
    
    DebugPrint.error("CLError.code = \(errorCode.code.rawValue)")
    
    switch errorCode.code {
      
    case .locationUnknown:
      notifyWatchers(withError: ErrorCode.managerFailUndeterminedLocation)
      DebugPrint.log("Unable to determine Location")
      
    case .denied:
      // User denied authorization
      manager.stopUpdatingLocation()
      currentLocation = nil
      notifyWatchers(withError: ErrorCode.managerFailDenied)
      DebugPrint.log("Unable to determine Location")
      
    default:
      notifyWatchers(withError: ErrorCode.managerFailUnknownError)
      DebugPrint.assert("Unrecognized fallthrough, error.localizedDescription = \(error.localizedDescription)")
    }
  }
  
  func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    // TODO
  }
}
