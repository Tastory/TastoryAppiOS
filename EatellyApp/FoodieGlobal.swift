//
//  FoodieGlobal.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-20.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import QuadratTouch


// MARK: - Types & Enums
typealias BooleanErrorBlock = (Bool, Error?) -> Void
typealias AnyErrorBlock = (Any?, Error?) -> Void
typealias SimpleErrorBlock = (Error?) -> Void
typealias UserErrorBlock = (FoodieUser?, Error?) -> Void


enum FoodieMediaType: String {
  case photo = "image/jpeg"
  case video = "video/mp4"
  //case unknown = "application/octet-stream"
}


struct FoodieGlobal {
  
  // MARK: - Constants
  struct Constants {
    static let ThumbnailPixels = 640.0
    static let JpegCompressionQuality: Double = 0.8
    static let ThemeColor: UIColor = .orange
    static let MomentsToBufferAtATime = 5
    static let JournalFeedPaginationCount = 50  // TODO: Need to implement pagination
    static let DefaultServerRequestRetryCount = 3
    static let DefaultServerRequestRetryDelay = 3.0
  }
  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case startupFoursquareCategoryError
    
    var errorDescription: String? {
      switch self {
      case .startupFoursquareCategoryError:
        return NSLocalizedString("Error acquiring Foursquare Categories on startup", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Static Variable
  private static let FoursquareClientID = "MIDYZC42VW5QCNEYMXZKH1XGEN4NMVRKZRX40SAPRDN3OQHM"
  private static let FoursquareClientSecret = "2UUA4PGJC5YTMQEUYUISWABLKJA50EUMO51WNVZQXJY1KGWO"
  private static let foursquareClient = Client(clientID: FoursquareClientID, clientSecret: FoursquareClientSecret, redirectURL: "")
  private static let foursquareConfiguration = Configuration(client: foursquareClient)
  private static var foursquareInitialized = false
  
  
  // MARK: - Public Static Variable
  static var foursquareSession: Session { return Session.sharedSession() }
  
  
  // MARK: - Public Static Functions
  static func booleanToSimpleErrorCallback(_ success: Bool, _ error: Error?, function: String = #function, file: String = #file, line: Int = #line, _ callback: SimpleErrorBlock?) {
    #if DEBUG  // Do this sanity check low and never need to worry about it again
      if (success && error != nil) || (!success && error == nil) {
        CCLog.fatal("Parse layer come back with Success and Error mismatch")
      }
    #endif
    
    if !success {
      CCLog.warning("\(function) Failed with Error - \(error!.localizedDescription) on line \(line) of \((file as NSString).lastPathComponent)")
    }
    callback?(error)
  }
  
  
  static func foursquareInitialize() {
    if !foursquareInitialized {
      let foursquareSessionQueue = OperationQueue()
      foursquareSessionQueue.qualityOfService = .userInitiated
      Session.setupSharedSessionWithConfiguration(foursquareConfiguration, completionQueue: foursquareSessionQueue)
      foursquareInitialized = true
    }
  }
}
