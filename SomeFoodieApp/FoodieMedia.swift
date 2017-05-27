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
    case saveToLocalwithNilimageMemoryBuffer
    case saveToLocalwithNilvideoLocalBufferUrl
    
    var errorDescription: String? {
      switch self {
      case .saveToLocalwithNilMediaType:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, medaiType = nil", comment: "Error description for an exception error code")
      case .saveToLocalwithNilimageMemoryBuffer:
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
  
  // Function for processing a completion from a child save
  func saveCompletionFromChild(to location: FoodieObject.StorageLocation,
                               withName name: String?,
                               withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
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
        callback?(false, ErrorCode.saveToLocalwithNilimageMemoryBuffer)
        return
      }
      saveDataBufferToLocal(buffer: memoryBuffer, withBlock: callback)
      
    case .video:
      guard let videoUrl = videoLocalBufferUrl else {
        callback?(false, ErrorCode.saveToLocalwithNilimageMemoryBuffer)
        return
      }
      saveTmpUrlToLocal(url: videoUrl, withBlock: callback)
    }
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}