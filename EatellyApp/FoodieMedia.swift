//
//  FoodieMedia.swift
//  EatellyApp
//
//  Created by Victor Tsang on 2017-05-08.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation


class FoodieMedia: FoodieS3Object {
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case retreiveFileDoesNotExist
    case saveToLocalwithNilMediaType
    case saveToLocalwithNilImageMemoryBuffer
    case saveToLocalwithNilvideoLocalBufferUrl
    
    var errorDescription: String? {
      switch self {
      case .retreiveFileDoesNotExist:
        return NSLocalizedString("File for filename does not exist", comment: "Error description for an exception error code")
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
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variable
  var imageMemoryBuffer: Data?
  var videoLocalBufferUrl: URL?
  var mediaType: FoodieMediaType?

  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  init() {
    super.init(withState: .notAvailable)
    foodieObject.delegate = self
  }
  
  
  // This is the Initializer we will call internally
  init(withState operationState: FoodieObject.OperationStates,
       for fileName: String,
       localType: FoodieObject.LocalType,
       mediaType: FoodieMediaType) {
    
    super.init(withState: operationState)
    foodieObject.delegate = self
    self.foodieFileName = fileName
    self.mediaType = mediaType
    
    // For videos, determine if the media file already exists in Local cache store
    if mediaType == .video && FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      videoLocalBufferUrl = FoodieFile.getFileURL(for: localType, with: fileName)
    } else {
      videoLocalBufferUrl = nil
    }
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMedia: FoodieObjectDelegate {
  
  func retrieveFromLocal(type localType: FoodieObject.LocalType,
                         forceAnyways: Bool,
                         withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieMedia has no foodieFileName")
    }
    
    guard let type = mediaType else {
      CCLog.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    // If photo and in memory, or video and in local, just callback
    if !forceAnyways && (imageMemoryBuffer != nil || videoLocalBufferUrl != nil) {
      DispatchQueue.global(qos: .userInitiated).async { callback?(nil) }
      return
    }
    
    switch type {
      
    case .photo:
      retrieveToBuffer(from: localType) { buffer, error in
        if let error = error {
          CCLog.warning("Retrieve from \(localType.rawValue) Failed - \(error.localizedDescription)")
        } else if let imageBuffer = buffer as? Data {
          self.imageMemoryBuffer = imageBuffer
        } else {
          CCLog.fatal("No Error, but no Buffer either. Cannot proceed")
        }
        callback?(error)
      }
      
    case .video:
      if checkIfExists(in: localType) {
        self.videoLocalBufferUrl = FoodieFile.getFileURL(for: .cache, with: fileName)
        callback?(nil)
      } else {
        callback?(ErrorCode.retreiveFileDoesNotExist)
      }
    }
  }
  
  
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   withBlock callback: FoodieObject.SimpleErrorBlock?) { // Always from Cache, then Server
    
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieMedia has no foodieFileName")
    }
    
    guard let type = mediaType else {
      CCLog.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    // If photo and in memory, or video and in local, just callback
    if !forceAnyways && (imageMemoryBuffer != nil || videoLocalBufferUrl != nil) {
      DispatchQueue.global(qos: .userInitiated).async { callback?(nil) }
      return
      
    } else if forceAnyways {
      
      switch type {
      case .photo:
        retrieveFromServerToBuffer() { buffer, error in
          if let error = error {
            CCLog.warning("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          }
          if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(error)
        }
        
      case .video:
        retrieveFromServerToLocal() { (error) in
          if let error = error {
            CCLog.warning("retrieveFromServerToLocal for video failed with error \(error.localizedDescription)")
          }
          self.videoLocalBufferUrl = FoodieFile.getFileURL(for: .cache, with: fileName)
          callback?(error)
        }
      }
      return
    }
    
    // If this is photo and not in memory, retrieve from local...
    switch type {
      
    case .photo:
      retrieveToBuffer(from: .cache) { buffer, error in
        guard let error = error as? FoodieFile.ErrorCode else {
          // Error is nil. This is actually success case!
          if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(nil)
          return
        }
        
        if error == FoodieFile.ErrorCode.fileManagerReadLocalNoFile {
          // This is expected when file is not cached to local
        } else {
          CCLog.warning("retrieveFromLocalToBuffer for photo failed with error \(error.localizedDescription)")
        }
        
        self.retrieveFromServerToBuffer() { (buffer, error) in
          if let error = error {
            CCLog.warning("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          }
          if let buffer = buffer as? Data { self.imageMemoryBuffer = buffer }
          callback?(error)
        }
      }
      
    case .video:
      retrieveFromServerToLocal() { error in
        if let err = error {
          CCLog.warning("retrieveFromServerToLocal for video failed with error \(err.localizedDescription)")
        }
        self.videoLocalBufferUrl = FoodieFile.getFileURL(for: .cache, with: fileName)
        callback?(error)
      }
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self. This object have no children
    retrieve(forceAnyways: forceAnyways, withBlock: callback)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }

    DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
      self.foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
    }
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
      saveTmpUrlToLocal(url: videoUrl) { /*[unowned self]*/ success, error in
        if success && error == nil {
          self.videoLocalBufferUrl = FoodieFile.getLocalFileURL(from: self.foodieFileName!)
        }
        callback?(success, error)
      }
    }
  }
  
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    CCLog.verbose("FoodieJournal.deleteRecursive \(getUniqueIdentifier())")
    
    // Delete itself first
    foodieObject.deleteObjectLocalNServer(withName: name, withBlock: callback)
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}
