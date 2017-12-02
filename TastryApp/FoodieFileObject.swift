//
//  FoodieFileManager.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-17.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AWSS3
import AWSCognito
import HTTPStatusCodes
import Foundation


class FoodieFileObject {
  
  // MARK: - Error Types
  enum FileErrorCode: LocalizedError {
    
    case fileManagerCopyItemLocalFailed
    case fileManagerMoveItemFromDownloadToLocalFailed
    case fileManagerReadLocalNoFile
    case fileManagerReadLocalFailed
    case fileManagerSaveLocalFailed
    case fileManagerRemoveItemLocalFailed
    case urlSessionDownloadHttpResponseNil
    case urlSessionDownloadHttpResponseFailed
    case urlSessionDownloadTempUrlNil
    case awsS3TransferManagerUploadRequestNil
    case awsS3TransferUploadCancelled
    case awsS3TransferUploadUnknownError
    case awsS3TransferManagerDownloadRequestNil
    case awsS3TransferDownloadCancelled
    case awsS3TransferDownloadUnknownError
    case awsS3FileDoesntExistError
    
    var errorDescription: String? {
      switch self {
      case .fileManagerCopyItemLocalFailed:
        return NSLocalizedString("FileManager.copyItem failed", comment: "Error description for an exception error code")
      case .fileManagerMoveItemFromDownloadToLocalFailed:
        return NSLocalizedString("FileManager.moveItem for URLSessionDownload failed", comment: "Error description for an exception error code")
      case .fileManagerReadLocalNoFile:
        return NSLocalizedString("Data(contentsOf:) no file found", comment: "Error description for an exception error code")
      case .fileManagerReadLocalFailed:
        return NSLocalizedString("Data(contentsOf:) failed", comment: "Error description for an exception error code")
      case .fileManagerSaveLocalFailed:
        return NSLocalizedString("Data.write failed", comment: "Error description for an exception error code")
      case .fileManagerRemoveItemLocalFailed:
        return NSLocalizedString("FileManager.removeItem failed", comment: "Error description for an exception error code")
      case .urlSessionDownloadHttpResponseNil:
        return NSLocalizedString("DownloadSession.downloadTask HTTP Response nil", comment: "Error description for an exception error code")
      case .urlSessionDownloadHttpResponseFailed:
        return NSLocalizedString("DownloadSession.downloadTask HTTP Response Failed", comment: "Error description for an exception error code")
      case .urlSessionDownloadTempUrlNil:
        return NSLocalizedString("DownloadSession.downloadTask Temp URL nil", comment: "Error description for an exception error code")
      case .awsS3TransferManagerUploadRequestNil:
        return NSLocalizedString("AWSS3TransferManagerUploadRequest returned nil", comment: "Error description for an exception error code")
      case .awsS3TransferUploadCancelled:
        return NSLocalizedString("AWS S3 Transfer Upload cancelled", comment: "Error description for an exception error code")
      case .awsS3TransferUploadUnknownError:
        return NSLocalizedString("AWS S3 Transfer Upload unknown error", comment: "Error description for an exception error code")
      case .awsS3TransferManagerDownloadRequestNil:
        return NSLocalizedString("AWSS3TransferManagerDownloadRequest returned nil", comment: "Error descipriton for an exception error code")
      case .awsS3TransferDownloadCancelled:
        return NSLocalizedString("AWS S3 Transfer Download cancelled", comment: "Error description for an exception error code")
      case .awsS3TransferDownloadUnknownError:
        return NSLocalizedString("AWS S3 Transfer Download unknonw error", comment: "Error description for an exception error code")
      case .awsS3FileDoesntExistError:
        return NSLocalizedString("AWS S3 File doesn't exist on server", comment: "Error description for an exception error code")
      }
    }
    
    init(_ FileErrorCode: FileErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = FileErrorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Constants
  struct Constants {
    static let S3BucketKey = "tastry-dev-howard"
    static let CloudFrontUrl = URL(string: "https://d2srw5n3q738u6.cloudfront.net/")!
    static let DraftStoryMediaFolderUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieObject.LocalType.draft.rawValue, isDirectory: true)
    static let CleanCrashLogFolderUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanCrashLog", isDirectory: true)  // Cleanroom Logger will be responsible for creating this directory
    static let CacheFoodieMediaFolderUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieObject.LocalType.cache.rawValue, isDirectory: true)
    static let TempFolderUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("FoodieTemp", isDirectory: true)
    static let AwsRetryCount = FoodieGlobal.Constants.DefaultServerRequestRetryCount
    static let AwsRetryDelay = FoodieGlobal.Constants.DefaultServerRequestRetryDelay
  }
  
  
  
  // MARK: - Private Static Variable
  private static let urlSession = URLSession(configuration: URLSessionConfiguration.default)
  
  
  
  // MARK: - Private Instance Variables
  private var uploadRequest: AWSS3TransferManagerUploadRequest?
  private var downloadTask: URLSessionDownloadTask?
  
  
  
  // MARK: - Public Instance Variable
  let foodieObject: FoodieObject = FoodieObject()
  var foodieFileName: String?
  
  
  
  // MARK: - Public Static Functions
  static func fileConfigure() {
    
    if AWSServiceManager.default().defaultServiceConfiguration == nil {
      let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAIIG7G45RQHBX3JGQ", secretKey: "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")
      let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider: credentialsProvider)
      AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    // Create some local directories
    do {
      try FileManager.default.createDirectory(at: Constants.DraftStoryMediaFolderUrl, withIntermediateDirectories: true, attributes: nil)
      try FileManager.default.createDirectory(at: Constants.CacheFoodieMediaFolderUrl, withIntermediateDirectories: true, attributes: nil)
      try FileManager.default.createDirectory(at: Constants.TempFolderUrl, withIntermediateDirectories: true, attributes: nil)
    } catch {
      CCLog.fatal("Cannot create required directories - \(error.localizedDescription)")
    }
  }
  
  
  static func newPhotoFileName() -> String {
    return "\(UUID().uuidString).jpg"
  }
  
  
  static func newVideoFileName() -> String {
    return "\(UUID().uuidString).mov"
  }
  
  
  static func thumbnailFileName(originalFileName: String) -> String {
    var fileNameComponents = originalFileName.components(separatedBy: ".")
    fileNameComponents.removeLast()
    
    var newFileName = String()
    
    for fileNameComponent in fileNameComponents {
      newFileName.append(fileNameComponent)
      
      if fileNameComponent != fileNameComponents.last {
        newFileName.append(".")
      }
    }
    return newFileName.appending("-Thumbnail.jpg")
  }
  
  
  static func getFileURL(for localType: FoodieObject.LocalType, with fileName: String) -> URL {
    switch localType {
    case .cache:
      return Constants.CacheFoodieMediaFolderUrl.appendingPathComponent(fileName, isDirectory: false)
    case .draft:
      return Constants.DraftStoryMediaFolderUrl.appendingPathComponent(fileName, isDirectory: false)
    }
  }
  
  
  static func getS3URL(for fileName: String) -> URL {
    return Constants.CloudFrontUrl.appendingPathComponent(fileName, isDirectory: false)
  }
  
  
  static func getRandomTempFileURL() -> URL {
    return Constants.TempFolderUrl.appendingPathComponent("\(UUID().uuidString).tmp", isDirectory: false)
  }
  
  
  static func checkIfExists(for fileName: String, in localType: FoodieObject.LocalType) -> Bool {
    let filePath = FoodieFileObject.getFileURL(for: localType, with: fileName).path
    return FileManager.default.isReadableFile(atPath: filePath)
  }
  
  
  static func checkIfExistsInS3(for fileName: String, withBlock callback: SimpleErrorBlock?) {
    guard let objRequest = AWSS3HeadObjectRequest() else {
      CCLog.fatal("Cannot create instance of S3 Head Object Request")
    }
    
    objRequest.bucket = Constants.S3BucketKey
    objRequest.key = fileName
    
    AWSS3.default().headObject(objRequest).continueWith() { task in
      if let error = task.error as NSError? {
        if error.domain == AWSS3ErrorDomain { // Can't nail down what the error code is really enumerated to.... , error.code == AWSS3ErrorType.noSuchKey || error.code == AWSS3ErrorType.unknown {
          callback?(FileErrorCode.awsS3FileDoesntExistError)
        } else {
          CCLog.warning("Check S3 if \(fileName) exists resulted in Error - \(error.localizedDescription)")
          callback?(error)
        }
        return nil
      }
      // found object
      callback?(nil)
      return nil
    }
  }

  
  static func deleteAll(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    var returnError: Error? = nil
    var directoryUrl: URL!
    
    switch localType {
    case .cache:
      directoryUrl = Constants.CacheFoodieMediaFolderUrl
    case .draft:
      directoryUrl = Constants.DraftStoryMediaFolderUrl
    }
    
    do {
      for contentUrl in try FileManager.default.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
        try FileManager.default.removeItem(at: contentUrl)
      }
    } catch {
      CCLog.warning("DeleteAll from \(localType) resulted in Exception - \(error.localizedDescription)")
      returnError = error
    }
    callback?(returnError)
  }
  
  
  static func cancelAll() {
    AWSS3TransferManager.default().cancelAll()
  }
  
  
  
  // MARK: - Private Instance Functions
  private func retrieveFromCloudfront(to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    
    let localFileURL = FoodieFileObject.getFileURL(for: localType, with: fileName)
    let serverFileURL = Constants.CloudFrontUrl.appendingPathComponent(fileName)
    
    let retrieveRetry = SwiftRetry()
    retrieveRetry.start("retrieve file '\(fileName)' from CloudFront", withCountOf: Constants.AwsRetryCount) { [unowned self] in
      CCLog.verbose("Retrieving from \(serverFileURL.absoluteString) for downloading \(fileName)")
      
      // Let's time the download!
      let downloadStartTime = PrecisionTime.now()
      self.downloadTask = FoodieFileObject.urlSession.downloadTask(with: serverFileURL) { (url, response, error) in
        let downloadEndTime = PrecisionTime.now()
        
        if let error = error {
          CCLog.warning("Download of \(fileName) from CloudFront resulted in error - \(error.localizedDescription)")
          
          if let urlError = error as? URLError {
            if !retrieveRetry.attemptRetryBasedOnURLError(urlError,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .utility) {
              callback?(urlError)
            }
          } else {
            callback?(error)
          }
          return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
          CCLog.assert("Did not receive HTTPURLResponse type or response = nil for downloading \(fileName)")
          callback?(FileErrorCode.urlSessionDownloadHttpResponseNil)
          return
        }
        
        guard let httpStatusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
          CCLog.warning("HTTPURLResponse.statusCode is invalid for downloading \(fileName)")
          callback?(FileErrorCode.urlSessionDownloadHttpResponseFailed)
          return
        }
        
        if  httpStatusCode != HTTPStatusCode.ok {
          CCLog.warning("HTTPURLResponse.statusCode = \(httpResponse.statusCode) for downloading \(fileName)")
          if !retrieveRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .utility) {
            callback?(FileErrorCode.urlSessionDownloadHttpResponseFailed)
          }
          return
        }
        
        guard let tempURL = url else {
          CCLog.assert("Download of \(fileName) from CloudFront resulted in url = nil")
          callback?(FileErrorCode.urlSessionDownloadTempUrlNil)
          return
        }
        
        // We are in success-land!
        #if DEBUG
          do {
            let timeDifference = downloadEndTime - downloadStartTime
            let fileAttribute = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSizeKb = Float(fileAttribute[FileAttributeKey.size] as! Int)/1000.0
            let avgDownloadSpeed = Float(fileSizeKb)/timeDifference.seconds  // KB/s
            CCLog.verbose("Download of \(fileName) of size \(fileSizeKb/1000.0) MB took \(timeDifference.milliSeconds) ms at \(avgDownloadSpeed) kB/s")
          } catch {
            CCLog.warning("Failed to get File Attribute for \(fileName)")
          }
        #endif
        
        do {
          try FileManager.default.moveItem(at: tempURL, to: localFileURL)
        } catch {
          let nsError = error as NSError
          if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteFileExistsError {
            CCLog.debug("File \(fileName) already exist in \(localType) after CloudFront download completion")
          } else {
            CCLog.assert("Failed to move file from URLSessionDownload temp to \(localType) as \(fileName). Error = \(error.localizedDescription)")
            callback?(error)
            return
          }
        }
        callback?(nil)
      }
      self.downloadTask!.resume()
    }
  }
  
  
  // MARK: - Public Instance Functions
  func retrieveToBuffer(from localType: FoodieObject.LocalType, withBlock callback: AnyErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    CCLog.debug("Retrieve \(fileName) from \(localType)")
    
    let buffer: Data?
    
    do {
      buffer = try Data(contentsOf: FoodieFileObject.getFileURL(for: localType, with: fileName))
    } catch {
      let nsError = error as NSError
      
      if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
        CCLog.info("No file '\(fileName) in local \(localType)")
        callback?(nil, FileErrorCode.fileManagerReadLocalNoFile)
        return
      } else {
        CCLog.warning("Failed to read file \(fileName) from local \(localType) - \(error.localizedDescription)")
        callback?(nil, FileErrorCode.fileManagerReadLocalFailed)
        return
      }
    }
    // Save to Local completed successfully!!
    callback?(buffer!, nil)
  }
  
  
  func retrieveFromServerToLocal(withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    CCLog.debug("Retrieve \(fileName) from S3 to Local Cache")
    
    // For now, would only ever retrieve from Server to Cache. Never to Draft
    retrieveFromCloudfront(to: .cache, withBlock: callback)
  }
  
  
  func retrieveFromServerToBuffer(withBlock callback: AnyErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    CCLog.debug("Retrieve \(fileName) from S3 to Local Cache")
    
    retrieveFromCloudfront(to: .cache) { error in
      if let error = error {
        CCLog.warning("Retrieve \(fileName) from S3 to Local Cache Failed - \(error.localizedDescription)")
        callback?(nil, error)
      } else {
        CCLog.debug("Retrieve \(fileName) from Local Cache")
        self.retrieveToBuffer(from: .cache, withBlock: callback)
      }
    }
  }
  
  
  func save(buffer: Data, to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFileObject.checkIfExists(for: fileName, in: localType) {
      CCLog.debug("Save Buffer as \(fileName) to \(localType)")
      
      do {
        try buffer.write(to: FoodieFileObject.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.assert("Failed to write media data to \(localType) as \(fileName)")
        callback?(FileErrorCode.fileManagerSaveLocalFailed)
        return
      }
      // Save to Local completed successfully!!
      callback?(nil)
    } else {
      CCLog.debug("File \(fileName) already exist. Skipping Save")
      callback?(nil)
    }
  }
  
  
  func copy(url: URL, to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFileObject.checkIfExists(for: fileName, in: localType) {
      CCLog.debug("Copy to \(localType) as \(fileName) from \(url.absoluteString)")
      
      do {
        try FileManager.default.copyItem(at: url, to: FoodieFileObject.getFileURL(for: localType, with: fileName))
//      // This is a little hacky.... Delete file after copy to Draft, assuming that the file was in Tmp
//      if localType == .draft {
//        try FileManager.default.removeItem(at: url)
//      }
      } catch {
        CCLog.assert("Failed to copy from \(url.absoluteString) to \(localType) as \(fileName)")
        callback?(FileErrorCode.fileManagerCopyItemLocalFailed)
        return
      }
      // Copy local completed successfully!!
      callback?(nil)
    } else {
      CCLog.debug("File \(fileName) already exist. Skipping Copy")
      callback?(nil)
    }
  }
  
  
  func saveToServer(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieFileObject has no foodieFileName")
    }
    
    FoodieFileObject.checkIfExistsInS3(for: fileName) { error in
      
      guard let error = error as? FoodieFileObject.FileErrorCode else {
        CCLog.debug("File \(fileName) already exists on S3. Skipping Save")
        callback?(nil)  // So the File exists. Assume already good and saved otherwise
        return
      }

      switch error {
      case .awsS3FileDoesntExistError:
        CCLog.debug("File \(fileName) does not exist on S3. Saving from \(localType)")
        
        let saveRetry = SwiftRetry()
        saveRetry.start("save file '\(fileName)' to S3", withCountOf: Constants.AwsRetryCount) { [unowned self] in
          
          guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
            CCLog.assert("AWSS3TransferManagerUploadRequest() returned nil")
            callback?(FileErrorCode.awsS3TransferManagerUploadRequestNil)
            return
          }
          
          uploadRequest.bucket = Constants.S3BucketKey
          uploadRequest.key = fileName
          uploadRequest.body = FoodieFileObject.getFileURL(for: localType, with: fileName)
          self.uploadRequest = uploadRequest
        
          AWSS3TransferManager.default().upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { task in
            
            if let error = task.error as NSError? {
              if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                switch code {
                  
                case .cancelled:
                  CCLog.debug("S3 upload for \(fileName) cancelled")
                  self.uploadRequest = nil
                  callback?(FileErrorCode.awsS3TransferUploadCancelled)
                  
                case .paused:
                  CCLog.fatal("S3 upload for \(fileName) paused. Pause is not currently supported")
                  
                default:
                  CCLog.warning("S3 upload for \(fileName) resulted in Error - \(error)")
                  if !saveRetry.attempt(after: Constants.AwsRetryDelay, withQoS: .utility) {
                    self.uploadRequest = nil
                    callback?(FileErrorCode.awsS3TransferUploadUnknownError)
                  }
                }
              } else {
                CCLog.warning("S3 upload for \(fileName) resulted in Error - \(error)")
                if !saveRetry.attempt(after: Constants.AwsRetryDelay, withQoS: .utility) {
                  self.uploadRequest = nil
                  callback?(FileErrorCode.awsS3TransferUploadUnknownError)
                }
              }
              return nil
            }
            // TODO: might be useful to store in parse for tracking the version
            CCLog.debug("AWS S3 Transfer Upload completed for \(fileName)")
            self.uploadRequest = nil
            callback?(nil)
            return nil
          }
        }
        return
        
      default:
        CCLog.warning("CheckIfFileExists on S3 for Save returned error - \(error.localizedDescription)")
        self.uploadRequest = nil
        callback?(error)
        return
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieFileObject has no foodieFileName")
    }
    
    if FoodieFileObject.checkIfExists(for: fileName, in: localType) {
      CCLog.debug("Delete \(fileName) from \(localType)")
      
      do {
        try FileManager.default.removeItem(at: FoodieFileObject.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.warning("Failed to delete \(fileName) from \(localType)")
        callback?(FileErrorCode.fileManagerRemoveItemLocalFailed)
      }
      // Delete local completed successfully!!
      callback?(nil)
    } else {
      CCLog.debug("File \(fileName) already not found from \(localType). Skipping Delete")
      callback?(nil)
    }
  }
  
  
  func deleteFromServer(withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieFileObject has no foodieFileName")
    }
    
    FoodieFileObject.checkIfExistsInS3(for: fileName) { error in
      if let error = error as? FoodieFileObject.FileErrorCode {
        switch error {
        case .awsS3FileDoesntExistError:
          CCLog.debug("File \(fileName) already not found on S3. Skipping Delete")
          callback?(nil)
          return
          
        default:
          CCLog.warning("CheckIfFileExists on S3 for Delete returned error - \(error.localizedDescription)")
          callback?(error)
          return
        }
      } else {
        CCLog.debug("File \(fileName) already exists on S3. Skipping Save")
        
        let delRequest = AWSS3DeleteObjectRequest()!
        delRequest.bucket = Constants.S3BucketKey
        delRequest.key = fileName
        
        let deleteRetry = SwiftRetry()
        deleteRetry.start("delete file '\(fileName)' from S3", withCountOf: Constants.AwsRetryCount) {
          
          AWSS3.default().deleteObject(delRequest).continueWith() { (task: AWSTask<AWSS3DeleteObjectOutput>) -> Any? in
            if let error = task.error {
              if !deleteRetry.attempt(after: Constants.AwsRetryDelay, withQoS: .userInitiated) {
                CCLog.warning("S3 delete for \(fileName) resulted in Error - \(error)")
                callback?(error)
              }
            } else {
              // Successfully deleted
              callback?(nil)
            }
            return nil
          }
        }
      }
    }
  }
  
  
  func deleteFromLocalNServer(withBlock callback: SimpleErrorBlock?) {
    
    // Just try to delete this from everywhere indiscriminately
    deleteFromServer { serverError in
      self.delete(from: .cache) { cacheError in
        self.delete(from: .draft) { draftError in
          callback?(serverError ?? cacheError ?? draftError)
        }
      }
    }
  }
  
  
  func cancelRetrieveFromServer() {
    if let downloadTask = downloadTask {
      // TODO: - If the Cancel comes in between Retry, it's gonna end bad.
      // Maybe the right way to do this is to loop the cancel until it's sure it's one that's in progress
      CCLog.debug("Download Task Cancel")
      downloadTask.cancel()  // Giving up Resume Data for now
    }
  }
  
  
  func cancelSaveToServer() {
    if let uploadRequest = uploadRequest {
      // TODO: - If the Cancel comes in between Retry, it's gonna end bad.
      // Maybe the right way to do this is to loop the cancel until it's sure it's one that's in progress
      CCLog.debug("Upload Request Cancel")
      uploadRequest.cancel()  // Giving up Resume Data for now
    }
  }
  
  
  func getUniqueIdentifier() -> String {
    return foodieFileName!
  }
}

