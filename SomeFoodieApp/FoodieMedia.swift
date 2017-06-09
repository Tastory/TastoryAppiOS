//
//  FoodieMedia.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-05-08.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import Foundation


class FoodieMedia: FoodieS3Object {
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case saveToLocalwithNilMediaType
    case saveToLocalwithNilImageMemoryBuffer
    case saveToLocalwithNilvideoLocalBufferUrl
    
    var errorDescription: String? {
      switch self {
      case .saveToLocalwithNilMediaType:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, medaiType = nil", comment: "Error description for an exception error code")
      case .saveToLocalwithNilImageMemoryBuffer:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, imageMemoryBuffer = nil", comment: "Error description for an exception error code")
      case .saveToLocalwithNilvideoLocalBufferUrl:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, videoLocalBufferUrl = nil", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  var imageMemoryBuffer: Data?
  var videoLocalBufferUrl: URL?
  
  
  // MARK: - Private Instance Variable
  var mediaType: FoodieMediaType?

  
  // MARK: - Public Instance Function
  override init() {
    super.init()
    foodieObject.delegate = self
  }
  
  init(fileName: String, type: FoodieMediaType) {
    super.init()
    foodieObject.delegate = self
    foodieFileName = fileName
    mediaType = type
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMedia: FoodieObjectDelegate {

  func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    guard let type = mediaType else {
      DebugPrint.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    // If photo and in memory, or video and in local, just callback
    if !forceAnyways && (imageMemoryBuffer != nil || videoLocalBufferUrl != nil) {
      callback?(self, nil)
      return
      
    } else if forceAnyways {
      
      switch type {
      case .photo:
        retrieveFromServerToBuffer() { [unowned self] buffer, error in
          if let err = error {
            DebugPrint.error("retrieveFromServerToBuffer for photo failed with error \(err.localizedDescription)")
          }
          if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(buffer, error)
        }
        
      case .video:
        retrieveFromServerToLocal() { (stringObject, error) in
          if let err = error {
            DebugPrint.error("retrieveFromServerToLocal for video failed with error \(err.localizedDescription)")
          }
          if let fileName = stringObject as? String {
            self.videoLocalBufferUrl = FoodieFile.createLocalFileURL(fileName: fileName)
          } else {
            DebugPrint.fatal("Cannot convert returned stringObject to String")
          }
          callback?(stringObject, error)
        }
      }
      return
    }
    
    // If this is photo and not in memory, retrieve from local...
    switch type {
      
    case .photo:
      retrieveFromLocalToBuffer() { [unowned self] localBuffer, localError in
        guard let err = localError else {
          // Error is nil. This is actually success case!
          if let imageBuffer = localBuffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(localBuffer, nil)
          return
        }
        DebugPrint.error("retrieveFromLocalToBuffer for photo failed with error \(err.localizedDescription)")
        
        self.retrieveFromServerToBuffer() { (serverBuffer, serverError) in
          if let error = serverError {
            DebugPrint.error("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          }
          if let imageBuffer = serverBuffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(serverBuffer, serverError)
        }
      }
      
    case .video:
      retrieveFromServerToLocal() { (stringObject, error) in
        if let err = error {
          DebugPrint.error("retrieveFromServerToLocal for video failed with error \(err.localizedDescription)")
        }
        if let fileName = stringObject as? String {
          self.videoLocalBufferUrl = FoodieFile.createLocalFileURL(fileName: fileName)
        } else {
          DebugPrint.fatal("Cannot convert returned stringObject to String")
        }
        callback?(stringObject, error)
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      self.foodieObject.savesCompletedFromAllChildren(to: location, withBlock: callback)
    }
  }
  
    
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }

  
  // Function to save this media object to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let type = mediaType else {
      callback?(false, ErrorCode.saveToLocalwithNilMediaType)
      return
    }
    switch type {
    case .photo:
      guard let memoryBuffer = imageMemoryBuffer else {
        callback?(false, ErrorCode.saveToLocalwithNilImageMemoryBuffer)
        return
      }
      saveDataBufferToLocal(buffer: memoryBuffer, withBlock: callback)
      
    case .video:
      guard let videoUrl = videoLocalBufferUrl else {
        callback?(false, ErrorCode.saveToLocalwithNilImageMemoryBuffer)
        return
      }
      saveTmpUrlToLocal(url: videoUrl, withBlock: callback)
    }
  }
  
  
  func verbose() {
    
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}
