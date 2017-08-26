//
//  SwiftRetry.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-08-21.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Foundation
import HTTPStatusCodes


// This retry is implemented assuming that there will be at least 1 Time-Out in the Request/Response chain. As such no time-out mechanism is needed
// This assumption might change. If so a reusable Time-out / Time-out + Retry mechanism should be built

class SwiftRetry {
  
  var requestName: String?
  var initialRetryCount: Int?
  var retryCount: Int?
  var retryRequest: (() -> Void)?
  
  // If the Retry object is created without having the retry count and retry request block initialized, Start needs to be called
  func start(_ name: String, withCountOf count: Int, _ requestBlock: @escaping () -> Void) {
    requestName = name
    initialRetryCount = count
    retryCount = count
    retryRequest = requestBlock
    requestBlock()
  }
  
  // Attempt retry if retry count is not 0. Otherwise return False.
  func attempt(after delaySeconds: Double = 0, withQoS serviceLevel: DispatchQoS.QoSClass = .background) -> Bool {
    guard let requestName = requestName, let retryCount = retryCount, let initialRetryCount = initialRetryCount, let retryRequest = retryRequest else {
      self.retryRequest = nil  // Make sure we break the reference cycle
      DebugPrint.assert("Retry attempted on uninitialized Swift Retry object")
      return false
    }
    
    if retryCount <= 1 {
      DebugPrint.verbose("All \(initialRetryCount) retry attempts of \(requestName) exhausted")
      self.retryRequest = nil  // Make sure we break the reference cycle
      return false
    } else {
      DebugPrint.verbose("Retrying \(requestName) #\(initialRetryCount - retryCount + 1)/\(initialRetryCount)")
      self.retryCount = retryCount - 1
      
      if delaySeconds != 0 {
        DispatchQueue.global(qos: serviceLevel).asyncAfter(deadline: .now() + delaySeconds, execute: retryRequest)
      } else {
        DispatchQueue.global(qos: serviceLevel).async(execute: retryRequest)
      }
      return true
    }
  }
  
  // Just break the reference cycle. Assumption is that ARC will clean up the rest
  func done() {
    retryRequest = nil
  }
  
  // Attempt retry as appropriate. Otherwise returns False.
  func attemptRetryBasedOnHttpStatus(httpStatus: HTTPStatusCode, after delaySeconds: Double = 0, withQoS serviceLevel: DispatchQoS.QoSClass = .background) -> Bool {
  
    switch httpStatus {
      
    case .ok:
      DebugPrint.assert("attemptRetryBasedOnHttpStatus() should only be used against non-good statuses")
      return false  // Should never be here to begin with
      
    // Add other explicity handlings here
      
    // Explicit retry cases
    case .gatewayTimeout, .requestTimeout, .iisLoginTimeout, .temporaryRedirect:
      if !attempt(after: delaySeconds, withQoS: serviceLevel) {
        DebugPrint.error("Retry attempts exhausted. Final \(httpStatus.description)")
        return false
      }
      
    default:
      // Class based retry cases
      if httpStatus.isInformational || httpStatus.isSuccess || httpStatus.isServerError {
        if !attempt(after: delaySeconds, withQoS: serviceLevel) {
          DebugPrint.error("Retry attempts exhausted. Final \(httpStatus.description)")
          return false
        }
      } else { // if httpStatus.isRedirection || httpStatus.isClientError {
        DebugPrint.error("Http Status failed. Retry not recommended - \(httpStatus.description)")
        done()
        return false
      }
    }
    return true
  }
  
  // Attempt retry as appropriate. Otherwise returns False.
  func attemptRetryBasedOnURLError(_ error: URLError, after delaySeconds: Double = 0, withQoS serviceLevel: DispatchQoS.QoSClass = .background) -> Bool {
    
//    guard let error = error.errorCode as? URLError.Code else {
//      DebugPrint.assert("Error received is not of URLError type")
//      return false
//    }
    
    switch error.code {
      
    case .timedOut, .secureConnectionFailed, .requestBodyStreamExhausted, .notConnectedToInternet, .networkConnectionLost, .httpTooManyRedirects, .downloadDecodingFailedMidStream, .downloadDecodingFailedToComplete, .dnsLookupFailed, .cannotLoadFromNetwork, .cannotFindHost, .cannotConnectToHost, .badServerResponse, .backgroundSessionWasDisconnected, .backgroundSessionInUseByAnotherProcess:
      
      if !attempt(after: delaySeconds, withQoS: serviceLevel) {
        DebugPrint.error("Retry attempts exhausted. Final URLError - \(error.localizedDescription)")
        return false
      }
      
    default:
      DebugPrint.error("NSURLError. Retry not recommended - \(error.localizedDescription)")
      return false
    }
    return true
  }
}
