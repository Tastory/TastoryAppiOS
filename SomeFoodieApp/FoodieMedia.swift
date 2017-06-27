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
  var imageMemoryBuffer: Data?
  var videoLocalBufferUrl: URL?
  
  
  // MARK: - Private Instance Variable
  var mediaType: FoodieMediaType?

  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  init() {
    super.init(withState: .notAvailable)
    foodieObject.delegate = self
  }
  
  
  // This is the Initializer we will call internally
  init(withState operationState: FoodieObject.OperationStates, fileName: String, type: FoodieMediaType) {
    super.init(withState: operationState)
    foodieObject.delegate = self
    foodieFileName = fileName
    mediaType = type
    
    // For videos, determine if the media file already exists in Local cache store
    if type == .video {
      videoLocalBufferUrl = FoodieFile.checkIfExistInLocal(for: fileName)
    }
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMedia: FoodieObjectDelegate {
  
  func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let type = mediaType else {
      DebugPrint.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    // If photo and in memory, or video and in local, just callback
    if !forceAnyways && (imageMemoryBuffer != nil || videoLocalBufferUrl != nil) {
      callback?(nil)
      return
      
    } else if forceAnyways {
      
      switch type {
      case .photo:
        retrieveFromServerToBuffer() { buffer, error in
          if let err = error {
            DebugPrint.error("retrieveFromServerToBuffer for photo failed with error \(err.localizedDescription)")
          }
          if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(error)
        }
        
      case .video:
        retrieveFromServerToLocal() { (error) in
          if let err = error {
            DebugPrint.error("retrieveFromServerToLocal for video failed with error \(err.localizedDescription)")
          }
          if let fileName = self.foodieFileName {
            self.videoLocalBufferUrl = FoodieFile.getLocalFileURL(from: fileName)
          } else {
            DebugPrint.fatal("FoodieMedia.retrieve() resulted in foodieFileName = nil")
          }
          callback?(error)
        }
      }
      return
    }
    
    // If this is photo and not in memory, retrieve from local...
    switch type {
      
    case .photo:
      retrieveFromLocalToBuffer() { localBuffer, localError in
        guard let err = localError as? FoodieFile.ErrorCode else {
          // Error is nil. This is actually success case!
          if let imageBuffer = localBuffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(nil)
          return
        }
        
        if err == FoodieFile.ErrorCode.fileManagerReadLocalNoFile {
          // This is expected when file is not cached to local
        } else {
          DebugPrint.error("retrieveFromLocalToBuffer for photo failed with error \(err.localizedDescription)")
        }
        
        self.retrieveFromServerToBuffer() { (serverBuffer, serverError) in
          if let error = serverError {
            DebugPrint.error("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          }
          if let imageBuffer = serverBuffer as? Data { self.imageMemoryBuffer = imageBuffer }
          callback?(serverError)
        }
      }
      
    case .video:
      retrieveFromServerToLocal() { error in
        if let err = error {
          DebugPrint.error("retrieveFromServerToLocal for video failed with error \(err.localizedDescription)")
        }
        if let fileName = self.foodieFileName {
          self.videoLocalBufferUrl = FoodieFile.getLocalFileURL(from: fileName)
        } else {
          DebugPrint.fatal("FoodieMedia.retrieve() resulted in foodieFileName = nil")
        }
        callback?(error)
      }
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self. This object have no children
    retrieve(forceAnyways: forceAnyways, withBlock: callback)
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

    DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
      self.foodieObject.savesCompletedFromAllChildren(to: location, withBlock: callback)
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
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieJournal.deleteRecursive \(getUniqueIdentifier())")
    
    // Delete itself first
    foodieObject.deleteObjectLocalNServer(withName: name, withBlock: callback)
  }
  
  func verbose() {
    
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}
