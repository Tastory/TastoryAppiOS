//
//  FoodieFileManager.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-17.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import AWSCore
import AWSCognito
import AWSS3
import HTTPStatusCodes
import Foundation


/*
 // AWS Developer Identity class for authenticating with AWS Cognito
 
 class AWSDeveloperIdentity : AWSCognitoCredentialsProviderHelper {
   override func token() -> AWSTask<NSString> {
   
   // Write code to call your backend:
   // pass username/password to backend or some sort of token to authenticate user, if successful,
   // from backend call getOpenIdTokenForDeveloperIdentity with logins map containing "your.provider.name":"enduser.username"
   // return the identity id and token to client
   // You can use AWSTaskCompletionSource to do this asynchronously
   
   // Set the identity id and return the token
   self.identityId = "us-west-2:dabdd18d-a121-47b8-9b0a-3fa5a0525e11"
   return AWSTask(result: "eyJraWQiOiJ1cy13ZXN0LTIxIiwidHlwIjoiSldTIiwiYWxnIjoiUlM1MTIifQ.eyJzdWIiOiJ1cy13ZXN0LTI6ZGFiZGQxOGQtYTEyMS00N2I4LTliMGEtM2ZhNWEwNTI1ZTExIiwiYXVkIjoidXMtd2VzdC0yOjE0MGZhYzIxLTYyY2ItNDdmMS1hNWMxLTYzYmE4ODZmYzIzNCIsImFtciI6WyJhdXRoZW50aWNhdGVkIiwic29tZWZvb2RpZS5zM3dyaXRlciIsInNvbWVmb29kaWUuczN3cml0ZXI6dXMtd2VzdC0yOjE0MGZhYzIxLTYyY2ItNDdmMS1hNWMxLTYzYmE4ODZmYzIzNDpzcGVjYyJdLCJpc3MiOiJodHRwczovL2NvZ25pdG8taWRlbnRpdHkuYW1hem9uYXdzLmNvbSIsImV4cCI6MTQ5NDcwMjA1OSwiaWF0IjoxNDk0NzAxMTU5fQ.fF6c3QdDxsHmdzz2dJyyI1bALjR5fhqkNJqBTFOnXDNQqLFAwJ-e17tjxdWO6crV3CLPyUBitjN1U8JGpdBANoOfsdpTRu7RAY12BdkxQ7Rt1bA7chNfoWWozjGDnUAMOczDAg2iC-kqdBaQJkBPCIBZmbbPWVs7dvvzThJAlRxoUMeQZ6TXr7jzpOihDOzakdKGeXv0iVonbbrBrYpP-LiJ6CwXv7rmyXI7iWgKmxUKvUtuMwZ2av9Csz07dCrFL2aYrtqLxA-zLbM3Lila7O21QGbpDjMdN8kFRKKcumuAwTHbevR2wh2q9XJ3p4NLjAGA3C1ZN1K3G0AIzDGMjg")
   }
 }
*/


class FoodieFile {
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case fileManagerCopyItemLocalFailed
    case fileManagerMoveItemFromDownloadToLocalFailed
    case fileManagerReadLocalNoFile
    case fileManagerReadLocalFailed
    case fileManagerSaveLocalFailed
    case fileManagerRemoveItemLocalFailed
    case urlSessionDownloadError
    case urlSessionDownloadNotUrlError
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
      case .urlSessionDownloadError:
        return NSLocalizedString("DownloadSession.downloadTask Error", comment: "Error description for an exception error code")
      case .urlSessionDownloadNotUrlError:
        return NSLocalizedString("DownloadSession.downloadTask error not a URLError", comment: "Error description for an exception error code")
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
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Private Constants
  struct Constants {
    static let S3BucketKey = "eatelly-dev-howard"
    static let CloudFrontUrl = URL(string: "https://d1axaetmqd29cm.cloudfront.net/")!
    static let DraftStoryMediaFolderUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieObject.LocalType.draft.rawValue, isDirectory: true)
    static let CleanCrashLogFolderUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanCrashLog", isDirectory: true)  // Cleanroom Logger will be responsible for creating this directory
    static let CacheFoodieMediaFolderUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieObject.LocalType.cache.rawValue, isDirectory: true)
    static let AwsRetryCount = FoodieGlobal.Constants.DefaultServerRequestRetryCount
    static let AwsRetryDelay = FoodieGlobal.Constants.DefaultServerRequestRetryDelay
  }
  
  
  
  // MARK: - Public Static Variables
  static var manager: FoodieFile!

  
  
  // MARK: - Private Instance Variables
  private let s3Handler: AWSS3
  private let fileManager: FileManager
  private let transferManager: AWSS3TransferManager
  private let downloadsSession: URLSession
  
  
  
  // MARK: - Public Static Functions
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
  
  
  // MARK: - Public Instance Functions
  init() {
    /*
     Authenticating with AWS Cognito
     let devAuth = AWSDeveloperIdentity(regionType: AWSRegionType.USWest2, identityPoolId: "us-west-2:140fac21-62cb-47f1-a5c1-63ba886fc234", useEnhancedFlow: true, identityProviderManager:nil)
     let credentialsProvider = AWSCognitoCredentialsProvider(regionType: AWSRegionType.USWest2, identityProvider:devAuth)
     let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider:credentialsProvider)
     AWSServiceManager.default().defaultServiceConfiguration = configuration
     */
    
    if AWSServiceManager.default().defaultServiceConfiguration == nil {
      let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAIIG7G45RQHBX3JGQ", secretKey: "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")
      let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider: credentialsProvider)
      AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    s3Handler = AWSS3.default()
    fileManager = FileManager.default
    transferManager = AWSS3TransferManager.default()
    downloadsSession = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
    
    // Create some local directories
    do {
      try self.fileManager.createDirectory(at: Constants.DraftStoryMediaFolderUrl, withIntermediateDirectories: true, attributes: nil)
      try self.fileManager.createDirectory(at: Constants.CacheFoodieMediaFolderUrl, withIntermediateDirectories: true, attributes: nil)
    } catch {
      CCLog.fatal("Cannot create required directories - \(error.localizedDescription)")
    }
  }
  
  
  func retrieve(from localType: FoodieObject.LocalType, with fileName: String, withBlock callback: AnyErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Make this an async call as the callback is expected to be not on the main thread
      let buffer: Data?

      do {
        buffer = try Data(contentsOf: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
          CCLog.info("No file '\(fileName) in local \(localType)")
          callback?(nil, ErrorCode.fileManagerReadLocalNoFile)
          return
        } else {
          CCLog.warning("Failed to read file \(fileName) from local \(localType) - \(error.localizedDescription)")
          callback?(nil, ErrorCode.fileManagerReadLocalFailed)
          return
        }
      }
      // Save to Local completed successfully!!
      callback?(buffer!, nil)
    }
  }
  
  
  // Cloudfront based implementation
  func retrieveFromS3(to localType: FoodieObject.LocalType, with fileName: String, withBlock callback: SimpleErrorBlock?) {
    
    let localFileURL = FoodieFile.getFileURL(for: localType, with: fileName)
    let serverFileURL = Constants.CloudFrontUrl.appendingPathComponent(fileName)
    
    let retrieveRetry = SwiftRetry()
    retrieveRetry.start("retrieve file '\(fileName)' from CloudFront", withCountOf: Constants.AwsRetryCount) {
      CCLog.verbose("Retrieving from \(serverFileURL.absoluteString) for downloading \(fileName)")
      
      // Let's time the download!
      let downloadStartTime = PrecisionTime.now()
      let downloadTask = self.downloadsSession.downloadTask(with: serverFileURL) { (url, response, error) in
        let downloadEndTime = PrecisionTime.now()
        
        guard let httpResponse = response as? HTTPURLResponse else {
          CCLog.assert("Did not receive HTTPURLResponse type or response = nil for downloading \(fileName)")
          callback?(ErrorCode.urlSessionDownloadHttpResponseNil)
          return
        }
        
        guard let httpStatusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
          CCLog.warning("HTTPURLResponse.statusCode is invalid for downloading \(fileName)")
          callback?(ErrorCode.urlSessionDownloadHttpResponseFailed)
          return
        }
        
        if  httpStatusCode != HTTPStatusCode.ok {
          CCLog.warning("HTTPURLResponse.statusCode = \(httpResponse.statusCode) for downloading \(fileName)")
          if !retrieveRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .userInitiated) {
            callback?(ErrorCode.urlSessionDownloadHttpResponseFailed)
          }
          return
        }
        
        if let downloadError = error {
          guard let urlError = downloadError as? URLError else {
            CCLog.assert("Download of \(fileName) from S3 resulted in error not of URLError type - \(downloadError.localizedDescription)")
            callback?(ErrorCode.urlSessionDownloadNotUrlError)
            return
          }
          
          CCLog.warning("Download of \(fileName) from S3 resulted in error - \(downloadError.localizedDescription)")
          if !retrieveRetry.attemptRetryBasedOnURLError(urlError,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .userInitiated) {
            callback?(ErrorCode.urlSessionDownloadError)
          }
          return
        }
        
        guard let tempURL = url else {
          CCLog.assert("Download of \(fileName) from S3 resulted in url = nil")
          callback?(ErrorCode.urlSessionDownloadTempUrlNil)
          return
        }

        // We are in success-land!
        #if DEBUG
        do {
          let timeDifference = downloadEndTime - downloadStartTime
          let fileAttribute = try self.fileManager.attributesOfItem(atPath: tempURL.path)
          let fileSizeKb = Float(fileAttribute[FileAttributeKey.size] as! Int)/1000.0
          let avgDownloadSpeed = Float(fileSizeKb)/timeDifference.seconds  // KB/s
          CCLog.verbose("Download of \(fileName) of size \(fileSizeKb/1000.0) MB took \(timeDifference.milliSeconds) ms at \(avgDownloadSpeed) kB/s")
        } catch {
          CCLog.warning("Failed to get File Attribute for \(fileName)")
        }
        #endif
        
        do {
          try self.fileManager.moveItem(at: tempURL, to: localFileURL)
        } catch {
          let nsError = error as NSError
          if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteFileExistsError {
            CCLog.debug("File \(fileName) already exist in \(localType) after S3 download completion")
          } else {
            CCLog.assert("Failed to move file from URLSessionDownload temp to \(localType) as \(fileName). Error = \(error.localizedDescription)")
            callback?(error)
            return
          }
        }
        callback?(nil)
      }
    
      downloadTask.resume()
    }
  }
  
  
  func save(to localType: FoodieObject.LocalType, from buffer: Data, with fileName: String, withBlock callback: SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Make this an async call as the callback is expected to be not on the main thread
      do {
        try buffer.write(to: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.assert("Failed to write media data to \(localType) as \(fileName)")
        callback?(ErrorCode.fileManagerSaveLocalFailed)
        return
      }
      // Save to Local completed successfully!!
      callback?(nil)
    }
  }
  
  
  func copyFile(from url: URL, to localType: FoodieObject.LocalType, with fileName: String, withBlock callback: SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
      do {
        try self.fileManager.copyItem(at: url, to: FoodieFile.getFileURL(for: localType, with: fileName))
        
        // This is a little hacky.... Delete file after copy to Draft, assuming that the file was in Tmp
        if localType == .draft {
          try self.fileManager.removeItem(at: url)
        }
      } catch {
        CCLog.assert("Failed to copy from \(url.absoluteString) to \(localType) as \(fileName)")
        callback?(ErrorCode.fileManagerCopyItemLocalFailed)
        return
      }
      // Copy local completed successfully!!
      callback?(nil)
    }
  }
  
  
  func saveToS3(from localType: FoodieObject.LocalType, with fileName: String, withBlock callback: SimpleErrorBlock?) {
    
    guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
      DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
        CCLog.assert("AWSS3TransferManagerUploadRequest() returned nil")
        callback?(ErrorCode.awsS3TransferManagerUploadRequestNil)
      }
      return
    }
    uploadRequest.bucket = Constants.S3BucketKey
    uploadRequest.key = fileName
    uploadRequest.body = FoodieFile.getFileURL(for: localType, with: fileName)

    let saveRetry = SwiftRetry()
    saveRetry.start("save file '\(fileName)' to S3", withCountOf: Constants.AwsRetryCount) {
      self.transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task:AWSTask<AnyObject>) -> Any? in
        
        if let error = task.error as NSError? {
          if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
            switch code {
            case .cancelled:
              CCLog.debug("S3 upload for \(fileName) cancelled")
              callback?(ErrorCode.awsS3TransferUploadCancelled)
            case .paused:
              CCLog.fatal("S3 upload for \(fileName) paused. Pause is not currently supported")
            default:
              CCLog.warning("S3 upload for \(fileName) resulted in Error - \(error)")
              if !saveRetry.attempt(after: Constants.AwsRetryDelay, withQoS: .userInitiated) {
                callback?(ErrorCode.awsS3TransferUploadUnknownError)
              }
            }
          } else {
            CCLog.warning("S3 upload for \(fileName) resulted in Error - \(error)")
            if !saveRetry.attempt(after: Constants.AwsRetryDelay, withQoS: .userInitiated) {
              callback?(ErrorCode.awsS3TransferUploadUnknownError)
            }
          }
          return nil
        }
        // TODO: might be useful to store in parse for tracking the version
        CCLog.debug("AWS S3 Transfer Upload completed for \(fileName)")
        callback?(nil)
        return nil
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType, with fileName: String, withBlock callback: SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
      do {
        try self.fileManager.removeItem(at: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.warning("Failed to delete \(fileName) from \(localType)")
        callback?(ErrorCode.fileManagerRemoveItemLocalFailed)
      }
      // Delete local completed successfully!!
      callback?(nil)
    }
  }


  func deleteFromS3(for fileName: String, withBlock callback: SimpleErrorBlock?) {
    let delRequest = AWSS3DeleteObjectRequest()!
    delRequest.bucket = Constants.S3BucketKey
    delRequest.key = fileName
    
    let deleteRetry = SwiftRetry()
    deleteRetry.start("delete file '\(fileName)' from S3", withCountOf: Constants.AwsRetryCount) {
      
      let deleteTask = self.s3Handler.deleteObject(delRequest)
      deleteTask.continueWith() { (task: AWSTask<AWSS3DeleteObjectOutput>) -> Any? in
        
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
  
  
  func deleteAll(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {

    var returnError: Error? = nil
    var directoryUrl: URL!

    switch localType {
    case .cache:
      directoryUrl = Constants.CacheFoodieMediaFolderUrl
    case .draft:
      directoryUrl = Constants.DraftStoryMediaFolderUrl
    }
    
    DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
      do {
        for contentUrl in try self.fileManager.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
          try self.fileManager.removeItem(at: contentUrl)
        }
      } catch {
        CCLog.warning("DeleteAll from \(localType) resulted in Exception - \(error.localizedDescription)")
        returnError = error
      }
      
      callback?(returnError)
    }
  }
  
  
  func checkIfExists(in localType: FoodieObject.LocalType, for fileName: String) -> Bool {
    let filePath = FoodieFile.getFileURL(for: localType, with: fileName).path
    return fileManager.isReadableFile(atPath: filePath)
  }
  
  
  func checkIfExistsInS3(for fileName: String, withBlock callback: SimpleErrorBlock?) {
    let objRequest = AWSS3HeadObjectRequest()!
    objRequest.bucket = Constants.S3BucketKey
    objRequest.key = fileName
    let task = s3Handler.headObject(objRequest)
    task.continueWith() { (task:AWSTask<AWSS3HeadObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
        if error.domain == AWSS3ErrorDomain { // Can't nail down what the error code is really enumerated to.... , error.code == AWSS3ErrorType.noSuchKey || error.code == AWSS3ErrorType.unknown {
          callback?(ErrorCode.awsS3FileDoesntExistError)
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
  
  
  func cancelAllS3Transfers()
  {
    transferManager.cancelAll()
  }
}


class FoodieS3Object {

  // MARK: - Public Instance Variable
  var foodieObject: FoodieObject!
  var foodieFileName: String?
  
  
  // MARK: - Public Static Functions
  static func deleteAll(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    FoodieFile.manager.deleteAll(from: localType, withBlock: callback)
  }
  
  
  // MARK: - Public Instance Functions  
  init() { foodieObject = FoodieObject() }

  
  func checkIfExists(in localType: FoodieObject.LocalType) -> Bool {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    return FoodieFile.manager.checkIfExists(in: localType, for: fileName)
  }
  
  
  func retrieveToBuffer(from localType: FoodieObject.LocalType, withBlock callback: AnyErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    CCLog.debug("Retrieve \(fileName) from \(localType)")
    FoodieFile.manager.retrieve(from: localType, with: fileName, withBlock: callback)
  }
  
  
  func retrieveFromServerToLocal(withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    CCLog.debug("Retrieve \(fileName) from S3 to Local Cache")
    FoodieFile.manager.retrieveFromS3(to: .cache, with: fileName, withBlock: callback)  // For now, would only ever retrieve from Server to Cache. Never to Draft
  }
  
  
  func retrieveFromServerToBuffer(withBlock callback: AnyErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    CCLog.debug("Retrieve \(fileName) from S3 to Local Cache")
    FoodieFile.manager.retrieveFromS3(to: .cache, with: fileName) { error in
      if let error = error {
        CCLog.warning("Retrieve \(fileName) from S3 to Local Cache Failed - \(error.localizedDescription)")
        callback?(nil, error)
      } else {
        CCLog.debug("Retreive \(fileName) from Local Cache")
        FoodieFile.manager.retrieve(from: .cache, with: fileName, withBlock: callback)
      }
    }
  }
  
  
  func save(buffer: Data, to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Save Buffer as \(fileName) to \(localType)")
      FoodieFile.manager.save(to: localType, from: buffer, with: fileName, withBlock: callback)
    } else {
      DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
        CCLog.debug("File \(fileName) already exist. Skipping Save")
        callback?(nil)
      }
    }
  }

  
  func copy(url: URL, to localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Copy to \(localType) as \(fileName) from \(url.absoluteString)")
      FoodieFile.manager.copyFile(from: url, to: localType, with: fileName, withBlock: callback)
    } else {
      DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
        CCLog.debug("File \(fileName) already exist. Skipping Copy")
        callback?(nil)
      }
    }
  }
  
  
  func saveToServer(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    FoodieFile.manager.checkIfExistsInS3(for: fileName) { error in
      if let error = error as? FoodieFile.ErrorCode {
        switch error {
        case .awsS3FileDoesntExistError:
          CCLog.debug("File \(fileName) does not exist on S3. Saving from \(localType)")
          FoodieFile.manager.saveToS3(from: localType, with: fileName, withBlock: callback)
          return
          
        default:
          CCLog.warning("CheckIfFileExists on S3 for Save returned error - \(error.localizedDescription)")
          callback?(error)
          return
        }
      } else {
        CCLog.debug("File \(fileName) already exists on S3. Skipping Save")
        callback?(nil)  // So the File exists. Assume already good and saved otherwise
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    if FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Delete \(fileName) from \(localType)")
      FoodieFile.manager.delete(from: localType, with: fileName, withBlock: callback)
    } else {
      DispatchQueue.global(qos: .userInitiated).async {  // Guarentee that callback comes back async from another thread
        CCLog.debug("File \(fileName) already not found from \(localType). Skipping Delete")
        callback?(nil)}
    }
  }
  
  
  func deleteFromServer(withBlock callback: SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    FoodieFile.manager.checkIfExistsInS3(for: fileName) { error in
      if let error = error as? FoodieFile.ErrorCode {
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
        FoodieFile.manager.deleteFromS3(for: fileName, withBlock: callback)
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
  
  
  func getUniqueIdentifier() -> String {
    return foodieFileName!
  }
}
