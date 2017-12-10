//
//  FoodieMedia.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-05-08.
//  Copyright © 2017 Tastry. All rights reserved.
//


import UIKit
import AVFoundation
import ImageIO
import MobileCoreServices

class FoodieMedia: FoodieFileObject {

  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case retrieveFileDoesNotExist
    case saveToLocalwithNilImageMemoryBuffer
    case saveToLocalWithNilvideoExportPlayer
    case saveToLocalVideoHasNoFileUrl
    case saveToLocalCompletedWithNoOutputFile
    
    var errorDescription: String? {
      switch self {
      case .retrieveFileDoesNotExist:
        return NSLocalizedString("File for filename does not exist", comment: "Error description for an exception error code")
      case .saveToLocalwithNilImageMemoryBuffer:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, imageMemoryBuffer = nil", comment: "Error description for an exception error code")
      case .saveToLocalWithNilvideoExportPlayer:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, videoLocalBufferUrl = nil", comment: "Error description for an exception error code")
      case .saveToLocalVideoHasNoFileUrl:
        return NSLocalizedString("FoodieMedia.saveToLocal failed, videoExportPlayer does not contain AVURLAsset", comment: "Error description for an exception error code")
      case .saveToLocalCompletedWithNoOutputFile:
        return NSLocalizedString("FoodieMedia.saveToLocal completed, but output file not found", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }

  
  
  // MARK: - Public Instance Variables
  
  var mediaType: FoodieMediaType?
  var imageMemoryBuffer: Data?
  
  
  
  // MARK: - Read Only Instance Variables
  
  private(set) var videoExportPlayer: AVExportPlayer?
  private(set) var localVideoUrl: URL?

  
  
  // MARK: - Public Instance Functions

  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init()
    foodieObject.delegate = self
  }
  
  
  // This is the Initializer we will call internally
  init(for fileName: String, localType: FoodieObject.LocalType, mediaType: FoodieMediaType) {
    super.init()
    foodieObject.delegate = self
    self.foodieFileName = fileName
    self.mediaType = mediaType
  }
  
  
  func setVideo(toLocal fileUrl: URL) {
    guard let mediaType = mediaType, mediaType == .video else {
      CCLog.fatal("MediaType not of Video when trying to set localVideoUrl")
    }
    guard fileUrl.isFileURL else {
      CCLog.fatal("External setting of localVideoUrl must be of local File URL")
    }
    localVideoUrl = fileUrl
  }
  
  
  func localVideoTranscode(to exportURL: URL,
                           thru tempURL: URL,
                           using preset: String = AVAssetExportPreset960x540,
                           with outputType: AVFileType = .mov,
                           duration timeRange: CMTimeRange? = nil,
                           completion callback: ((Error?) -> Void)? = nil) {
    
    guard let localVideoUrl = localVideoUrl else {
      CCLog.fatal("localVideoUrl = nil")
    }
    
    // To do the exporter, we need an AVExportPlayer, so create one, and we'll let it clean itself up after it finished switching backing
    videoExportPlayer = AVExportPlayer()
    videoExportPlayer!.initAVPlayer(from: localVideoUrl)
    videoExportPlayer!.exportAsync(to: exportURL,
                               thru: tempURL,
                               using: preset,
                               with: outputType,
                               duration: timeRange,
                               completion: callback)
  }
  
  
  func generateThumbnail() -> FoodieMedia? {
    // Obtain thumbnail, width and aspect ratio ahead of time once view is already loaded
    let thumbnailCgImage: CGImage!
    
    // Need to decide what image to set as thumbnail
    switch mediaType! {
    case .photo:
      guard let imageBuffer = imageMemoryBuffer else {
        // TODO not sure how we can display a dialog within this model if an error does occur
        // there used to be display internal dialog here before
        CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return nil
      }
      
      guard let imageSource = CGImageSourceCreateWithData(imageBuffer as CFData, nil) else {
        CCLog.assert("CGImageSourceCreateWithData() failed")
        return nil
      }
      
      let options = [
        kCGImageSourceThumbnailMaxPixelSize as String : FoodieGlobal.Constants.ThumbnailPixels as NSNumber,
        kCGImageSourceCreateThumbnailFromImageAlways as String : true as NSNumber,
        kCGImageSourceCreateThumbnailWithTransform as String: true as NSNumber
      ]
      thumbnailCgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)  // Assuming either portrait or square
      
      // Get the width and aspect ratio while at it
      let imageCount = CGImageSourceGetCount(imageSource)
      
      if imageCount != 1 {
        CCLog.assert("Image Source Count not 1")
        return nil
      }
      
//      guard let imageProperties = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String : AnyObject]) else {
//        CCLog.assert("CGImageSourceCopyPropertiesAtIndex failed to get Dictionary of image properties")
//        return nil
//      }
//      
//      if let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? Int {
//      } else {
//        CCLog.assert("Image property with index kCGImagePropertyPixelWidth did not return valid Integer value")
//        return nil
//      }
//
//      if let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? Int {
//      } else {
//        CCLog.assert("Image property with index kCGImagePropertyPixelHeight did not return valid Integer value")
//        return nil
//      }
      
    case .video:      // TODO: Allow user to change timeframe in video to base Thumbnail on
      guard let localVideoUrl = localVideoUrl else {
        CCLog.fatal("Cannot generate thumbnail without local video URL")
      }
      
      let asset = AVURLAsset(url: localVideoUrl)
      let imgGenerator = AVAssetImageGenerator(asset: asset)
      
      imgGenerator.maximumSize = CGSize(width: FoodieGlobal.Constants.ThumbnailPixels, height: FoodieGlobal.Constants.ThumbnailPixels)  // Assuming either portrait or square
      imgGenerator.appliesPreferredTrackTransform = true
      
      do {
        thumbnailCgImage = try imgGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
      } catch {
        CCLog.assert("AVAssetImageGenerator.copyCGImage failed with error: \(error.localizedDescription)")
        return nil
      }
      
      let avTracks = asset.tracks(withMediaType: AVMediaType.video)
      
      if avTracks.count != 1 {
        CCLog.assert("There isn't exactly 1 video track for the AVURLAsset")
        return nil
      }
      
//      let videoSize = avTracks[0].naturalSize
    }
    
    // Create a Thumbnail Media with file name based on the original file name of the Media
    guard let foodieFileName = foodieFileName else {
      CCLog.assert("Unexpected. foodieFileName = nil")
      return nil
    }
    
    let thumbnailObj = FoodieMedia(for: FoodieFileObject.thumbnailFileName(originalFileName: foodieFileName), localType: .draft, mediaType: .photo)
    thumbnailObj.imageMemoryBuffer = UIImageJPEGRepresentation(UIImage(cgImage: thumbnailCgImage), CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
    return thumbnailObj
  }
}



// MARK: - Foodie Object Delegate Conformance
extension FoodieMedia: FoodieObjectDelegate {
  
  var isRetrieved: Bool {
    if let mediaType = mediaType {
      switch mediaType {
      case .photo:
        return (imageMemoryBuffer != nil)
        
      case .video:
        if let localVideoUrl = localVideoUrl, FileManager.default.fileExists(atPath: localVideoUrl.path) {
          return true  // !!! For this case, it's not possible to tell if it's retrieved, or retrieving
        } else {
          return false
        }
      }
    }
    return false
  }
  
  
  var isReady: Bool {
    if let mediaType = mediaType {
      switch mediaType {
      case .photo:
        return (imageMemoryBuffer != nil)
        
      case .video:
        if let videoExportPlayer = videoExportPlayer, videoExportPlayer.avPlayer != nil {
          return true  // Retrieving case
        } else if let localVideoUrl = localVideoUrl, FileManager.default.fileExists(atPath: localVideoUrl.path) {
          return true  // Retrieved case
        } else {
          return false
        }
      }
    }
    return false
  }
  
  
  func retrieve(from localType: FoodieObject.LocalType,
                forceAnyways: Bool,
                withBlock callback: SimpleErrorBlock?) {
    
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieMedia has no foodieFileName")
    }
    
    guard let type = mediaType else {
      CCLog.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    // If photo and in memory, or video in player, just callback
    if !forceAnyways && isRetrieved {
      callback?(nil)
      return
    }
    
    switch type {
      
    case .photo:
      retrieveToBuffer(from: localType) { buffer, error in
        if let error = error {
          CCLog.warning("Retrieve from \(localType) Failed - \(error.localizedDescription)")
        } else if let imageBuffer = buffer as? Data {
          self.imageMemoryBuffer = imageBuffer
        } else {
          CCLog.fatal("No Error, but no Buffer either. Cannot proceed")
        }
        callback?(error)
      }
      
    case .video:
      if FoodieFileObject.checkIfExists(for: fileName, in: localType) {
        self.localVideoUrl = FoodieFileObject.getFileURL(for: localType, with: fileName)
        callback?(nil)
      } else {
        callback?(ErrorCode.retrieveFileDoesNotExist)
      }
    }
  }
  
  
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   type localType: FoodieObject.LocalType,
                                   withReady readyBlock: SimpleBlock? = nil,
                                   withCompletion callback: SimpleErrorBlock?) {
    
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieMedia has no foodieFileName")
    }
    
    guard let type = mediaType else {
      CCLog.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    guard localType == .cache else {
      CCLog.fatal("Only allowing Server to Cache, not to Draft")
    }
    
    // If photo and in memory, or video and in player, just callback
    var isVideoFromServerAndNotInCache = false
    if localType == .cache, type == .video, !FoodieFileObject.checkIfExists(for: fileName, in: .cache) {
      isVideoFromServerAndNotInCache = true
    }
    
    if !forceAnyways, isRetrieved, !isVideoFromServerAndNotInCache {
      readyBlock?()  // !!! Only called if successful. Let it spin forever until a successful retrieval?
      callback?(nil)
      return
      
    } else if forceAnyways {
      
      switch type {
      case .photo:
        retrieveFromServerToBuffer() { buffer, error in
          if let error = error {
            CCLog.warning("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          } else {
            if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
            readyBlock?()  // !!! Only called if successful. Let it spin forever until a successful retrieval
          }
          callback?(error)
        }
        
      case .video:
        videoExportPlayer = AVExportPlayer()
        videoExportPlayer!.initAVPlayer(from: FoodieFileObject.getS3URL(for: fileName))
        videoExportPlayer!.exportAsync(to: FoodieFileObject.getFileURL(for: .cache, with: fileName), thru: FoodieFileObject.getRandomTempFileURL()) { error in
          self.videoExportPlayer = nil  // FoodieMedia only hole onto the Export Player during transcode/export. Releases all players when done
          
          if let error = error {
            CCLog.warning("AVExportPlayer export asynchronously failed with error \(error.localizedDescription)")
            callback?(error)
          } else if FoodieFileObject.checkIfExists(for: fileName, in: .cache) {
            self.localVideoUrl = FoodieFileObject.getFileURL(for: .cache, with: fileName)
            callback?(nil)
          } else {
            CCLog.fatal("AVExportPlayer export has no error, but no file output")
          }
        }
        readyBlock?()  // !!! We provide ready state early here, because we deem a video ready to stream as soon as it starts downloading
      }
      return
    }
    
    // If this is photo and not in memory, retrieve from local...
    switch type {
      
    case .photo:
      
      // This is Local Case
      retrieveToBuffer(from: .cache) { buffer, error in
        guard let error = error as? FoodieFileObject.FileErrorCode else {
          // Error is nil. This is actually success case!
          if let imageBuffer = buffer as? Data { self.imageMemoryBuffer = imageBuffer }
          readyBlock?()  // !!! Only called if successful. Let it spin forever until a successful retrieval
          callback?(nil)
          return
        }
        
        if error == FoodieFileObject.FileErrorCode.fileManagerReadLocalNoFile {
          // This is expected when file is not cached to local
        } else {
          CCLog.warning("retrieveFromLocalToBuffer for photo failed with error \(error.localizedDescription)")
        }
        
        // This is Server Case
        self.retrieveFromServerToBuffer() { (buffer, error) in
          if let error = error {
            CCLog.warning("retrieveFromServerToBuffer for photo failed with error \(error.localizedDescription)")
          } else {
            if let buffer = buffer as? Data { self.imageMemoryBuffer = buffer }
            readyBlock?()  // !!! Only called if successful. Let it spin forever until a successful retrieval
          }
          callback?(error)
        }
      }
      
    case .video:
      // This is Local Case
      guard !FoodieFileObject.checkIfExists(for: fileName, in: .cache) else {
        self.localVideoUrl = FoodieFileObject.getFileURL(for: .cache, with: fileName)
        readyBlock?()  // !!! Only called if successful. Let it spin forever until a successful retrieval
        callback?(nil)
        return
      }

      // This is Server Case
      videoExportPlayer = AVExportPlayer()
      videoExportPlayer!.initAVPlayer(from: FoodieFileObject.getS3URL(for: fileName))
      videoExportPlayer!.exportAsync(to: FoodieFileObject.getFileURL(for: .cache, with: fileName), thru: FoodieFileObject.getRandomTempFileURL()) { error in
        self.videoExportPlayer = nil  // FoodieMedia only hole onto the Export Player during transcode/export. Releases all players when done
        
        if let error = error {
          CCLog.warning("AVExportPlayer export asynchronously failed with error \(error.localizedDescription)")
          callback?(error)
        } else if FoodieFileObject.checkIfExists(for: fileName, in: .cache) {
          self.localVideoUrl = FoodieFileObject.getFileURL(for: .cache, with: fileName)
          callback?(nil)
        } else {
          CCLog.fatal("AVExportPlayer export has no error, but no file output")
        }
      }
      readyBlock?()  // !!! We provide ready state early here, because we deem a video ready to stream as soon as it starts downloading
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         for parentOperation: AsyncOperation? = nil,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    // Retrieve self. This object have no children
    switch location {
    case .local:
      retrieve(from: localType, forceAnyways: forceAnyways) { error in
        if error == nil {
          readyBlock?()
        }
        callback?(error)
      }
      
    case .both:
      retrieveFromLocalThenServer(forceAnyways: forceAnyways, type: localType, withReady: readyBlock, withCompletion: callback)
    }
    
    return nil
  }

  
  // Function to save this media object to local.
  func save(to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieMedia has no foodieFileName")
    }
    
    guard let type = mediaType else {
      CCLog.fatal("Retrieve not allowed when Media has no MediaType")
    }
    
    switch type {
    case .photo:
      guard let memoryBuffer = self.imageMemoryBuffer else {
        CCLog.assert("imageMemoryBuffer = nil when Saving Media \(getUniqueIdentifier()) to Local")
        callback?(ErrorCode.saveToLocalwithNilImageMemoryBuffer)
        return
      }
      self.save(buffer: memoryBuffer, to: localType, withBlock: callback)

    case .video:
      guard let sourceURL = localVideoUrl else {
        CCLog.assert("Cannot access AVURLAsset from Video Export Player when Saving Media \(getUniqueIdentifier()) to Local")
        callback?(ErrorCode.saveToLocalVideoHasNoFileUrl)
        return
      }

      self.copy(url: sourceURL, to: localType) { error in
        if error == nil {
          self.localVideoUrl = FoodieFileObject.getFileURL(for: localType, with: fileName)
        }
        callback?(error)
      }
    }
  }
  
  
  // Function to Save to both Local & Server
  func saveToLocalNServer(type localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    // Save to Local first, then Server.
    save(to: localType) { error in
      
      if let error = error {
        CCLog.warning("Save to Local in Save to Local & Server failed - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      self.saveToServer(from: localType, withBlock: callback)
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation? = nil,
                     withBlock callback: SimpleErrorBlock?) {
    
    self.foodieObject.saveObject(to: location, type: localType, withBlock: callback)
  }
  
  
  func saveWhole(to location: FoodieObject.StorageLocation,
                 type localType: FoodieObject.LocalType,
                 for parentOperation: AsyncOperation? = nil,
                 withBlock callback: SimpleErrorBlock?) {
    
    self.foodieObject.saveObject(to: location, type: localType, withBlock: callback)
  }
  
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation? = nil,
                       withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("FoodieStory.deleteRecursive \(getUniqueIdentifier())")
    
    // Delete itself first
    foodieObject.deleteObject(from: location, type: localType) { error in
      
      guard let mediaType = self.mediaType else {
        CCLog.fatal("FoodieMedia has no mediaType")
      }
      
      if mediaType == .video {
        guard let fileName = self.foodieFileName else {
          CCLog.fatal("FoodieMedia has no foodieFileName")
        }
        
        // If the file is deleted from 1 local type, see if we should switch to the other?
        switch localType {
        case .cache:
          if FoodieFileObject.checkIfExists(for: fileName, in: .draft) {
            self.localVideoUrl = FoodieFileObject.getFileURL(for: .draft, with: fileName)
          } else {
            self.localVideoUrl = nil
          }
        case .draft:
          if FoodieFileObject.checkIfExists(for: fileName, in: .cache) {
            self.localVideoUrl = FoodieFileObject.getFileURL(for: .cache, with: fileName)
          } else {
            self.localVideoUrl = nil
          }
        }
      }
      callback?(error)
    }
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    cancelRetrieveFromServer()
    if let videoExportPlayer = videoExportPlayer {
      videoExportPlayer.cancelExport()  // On successful export cancel, the retrieve completion failure will nil the videoExportPlayer pointer
    }
  }
  
  
  func cancelSaveToServerRecursive() {
    cancelSaveToServer()
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}
