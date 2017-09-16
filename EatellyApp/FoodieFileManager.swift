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
    
    case fileManagerMoveItemLocalFailed
    case fileManagerMoveItemFromDownloadToLocalFailed
    case fileManagerReadLocalNoFile
    case fileManagerReadLocalFailed
    case fileManagerSaveLocalFailed
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
      case .fileManagerMoveItemLocalFailed:
        return NSLocalizedString("FileManager.moveItem failed", comment: "Error description for an exception error code")
      case .fileManagerMoveItemFromDownloadToLocalFailed:
        return NSLocalizedString("FileManager.moveItem for URLSessionDownload failed", comment: "Error description for an exception error code")
      case .fileManagerReadLocalNoFile:
        return NSLocalizedString("Data(contentsOf:) no file found", comment: "Error description for an exception error code")
      case .fileManagerReadLocalFailed:
        return NSLocalizedString("Data(contentsOf:) failed", comment: "Error description for an exception error code")
      case .fileManagerSaveLocalFailed:
        return NSLocalizedString("Data.write failed", comment: "Error description for an exception error code")
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
    static let DraftStoryMediaFolderUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieLocalType.draft.rawValue, isDirectory: true)
    static let CleanCrashLogFolderUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("CleanCrashLog", isDirectory: true)
    static let CacheFoodieMediaFolderUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(FoodieLocalType.cache.rawValue, isDirectory: true)
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
  
  
  static func getFileURL(for localType: FoodieLocalType, with fileName: String) -> URL {
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
  }
  
  
  func retrieve(from localType: FoodieLocalType, with fileName: String, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Make this an async call as the callback is expected to be not on the main thread
      let buffer: Data?

      do {
        buffer = try Data(contentsOf: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
          CCLog.info("No file '\(fileName) in local directory")
          callback?(nil, ErrorCode.fileManagerReadLocalNoFile)
          return
        } else {
          CCLog.warning("Failed to read file \(fileName) from local Documents folder \(error.localizedDescription)")
          callback?(nil, ErrorCode.fileManagerReadLocalFailed)
          return
        }
      }
      // Save to Local completed successfully!!
      callback?(buffer!, nil)
    }
  }
  
  
  // Cloudfront based implementation
  func retrieveFromS3(to localType: FoodieLocalType, with fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    let localFileURL = FoodieFile.getFileURL(for: localType, with: fileName)
    let serverFileURL = Constants.CloudFrontUrl.appendingPathComponent(fileName)
    
    let retrieveRetry = SwiftRetry()
    retrieveRetry.start("retrieve file '\(fileName)' from CloudFront", withCountOf: Constants.AwsRetryCount) {
      CCLog.verbose("retrievingFrom \(serverFileURL.absoluteString)")
      
      // Let's time the download!
      let downloadStartTime = PrecisionTime.now()
      let downloadTask = self.downloadsSession.downloadTask(with: serverFileURL) { (url, response, error) in
        let downloadEndTime = PrecisionTime.now()
        
        guard let httpResponse = response as? HTTPURLResponse else {
          CCLog.assert("Unexpected. Did not receive HTTPURLResponse type or response = nil")
          callback?(ErrorCode.urlSessionDownloadHttpResponseNil)
          return
        }
        
        guard let httpStatusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
          CCLog.warning("Download HTTPURLResponse.statusCode is invalid")
          callback?(ErrorCode.urlSessionDownloadHttpResponseFailed)
          return
        }
        
        if  httpStatusCode != HTTPStatusCode.ok {
          CCLog.warning("Download HTTPURLResponse.statusCode = \(httpResponse.statusCode)")
          if !retrieveRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .userInitiated) {
            callback?(ErrorCode.urlSessionDownloadHttpResponseFailed)
          }
          return
        }
        
        if let downloadError = error {
          guard let urlError = downloadError as? URLError else {
            CCLog.assert("Download error is not URLError type - \(downloadError.localizedDescription)")
            callback?(ErrorCode.urlSessionDownloadNotUrlError)
            return
          }
          
          CCLog.warning("Download error: \(downloadError.localizedDescription)")
          if !retrieveRetry.attemptRetryBasedOnURLError(urlError,
                                                          after: Constants.AwsRetryDelay,
                                                          withQoS: .userInitiated) {
            callback?(ErrorCode.urlSessionDownloadError)
          }
          return
        }
        
        guard let tempURL = url else {
          CCLog.assert("Unexpected. Local url = nil")
          callback?(ErrorCode.urlSessionDownloadTempUrlNil)
          return
        }

        // We are in success-land!
        let timeDifference = downloadEndTime - downloadStartTime
        //try? self.fileManager.removeItem(at: localFileURL)  // TODO: If the file already exists, really shouldn't call this anyways.
        
        do {
          let fileAttribute = try self.fileManager.attributesOfItem(atPath: tempURL.path)
          let fileSizeKb = Float(fileAttribute[FileAttributeKey.size] as! Int)/1000.0
          let avgDownloadSpeed = Float(fileSizeKb)/timeDifference.seconds  // KB/s
          
          CCLog.verbose("Download of \(fileName) of size \(fileSizeKb/1000.0) MB took \(timeDifference.milliSeconds) ms at \(avgDownloadSpeed) kB/s")
          
          try self.fileManager.copyItem(at: tempURL, to: localFileURL)
        } catch {
          CCLog.assert("Failed to move file from URLSessionDownload temp to local Documents folder. Erorr = \(error.localizedDescription)")
          callback?(ErrorCode.fileManagerMoveItemFromDownloadToLocalFailed)
          return
        }
        callback?(nil)
      }
    
      downloadTask.resume()
    }
  }
  
  
  func save(to localType: FoodieLocalType, from buffer: Data, with fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {  // Make this an async call as the callback is expected to be not on the main thread
      do {
        try buffer.write(to: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.assert("Failed to write media data to local Documents folder \(error.localizedDescription)")
        callback?(ErrorCode.fileManagerSaveLocalFailed)
        return
      }
      // Save to Local completed successfully!!
      callback?(nil)
    }
  }
  
  
  func moveFile(from url: URL, to localType: FoodieLocalType, with fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.fileManager.moveItem(at: url, to: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.assert("Failed to move media file to local Documents folder \(error.localizedDescription)")
        callback?(ErrorCode.fileManagerMoveItemLocalFailed)
        return
      }
      // Move local completed successfully!!
      callback?(nil)
    }
  }
  
  
  func saveToS3(from localType: FoodieLocalType, with fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
      CCLog.assert("AWSS3TransferManagerUploadRequest() returned nil")
      callback?(ErrorCode.awsS3TransferManagerUploadRequestNil)
      return
    }
    uploadRequest.bucket = Constants.S3BucketKey
    uploadRequest.key = fileName
    uploadRequest.body = FoodieFile.getFileURL(for: localType, with: fileName)

    transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task:AWSTask<AnyObject>) -> Any? in
      
      if let error = task.error as NSError? {
        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
          switch code {
          case .cancelled:
            CCLog.debug("AWS Transfer Upload with Key \(uploadRequest.key!) cancelled")
            callback?(ErrorCode.awsS3TransferUploadCancelled)
          case .paused:
            CCLog.fatal("Pause is not well understood and not currently supported. Pulling a Fatal condition for now")
          default:
            CCLog.warning("AWS Transfer Upload with Key \(String(describing: uploadRequest.key)) resulted in Error: \(error)")
            callback?(ErrorCode.awsS3TransferUploadUnknownError)
          }
        } else {
          CCLog.warning("AWS Transfer Upload with Key \(String(describing: uploadRequest.key)) resulted in Error: \(error)")
          callback?(ErrorCode.awsS3TransferUploadUnknownError)
        }
        return nil
      }
      // TODO: might be useful to store in parse for tracking the version
      CCLog.debug("AWS Transfer Upload completed for Key \(uploadRequest.key!)")
      callback?(nil)
      return nil
    }
  }
  
  
  func delete(from localType: FoodieLocalType, with fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.fileManager.removeItem(at: FoodieFile.getFileURL(for: localType, with: fileName))
      } catch {
        CCLog.warning("Failed to delete media file from local Documents foler \(error.localizedDescription)")
        callback?(ErrorCode.fileManagerMoveItemLocalFailed)
      }
      // Delete local completed successfully!!
      callback?(nil)
    }
  }


  func deleteFromS3(for fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    let delRequest = AWSS3DeleteObjectRequest()!
    delRequest.bucket = Constants.S3BucketKey
    delRequest.key = fileName
    
    let deleteTask = s3Handler.deleteObject(delRequest)
    deleteTask.continueWith() { (task: AWSTask<AWSS3DeleteObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
        callback?(error)
      }
      // Successfully deleted
      callback?(nil)
      return nil
    }
  }
  
  
  func checkIfExists(in localType: FoodieLocalType, for fileName: String) -> Bool {
    let filePath = FoodieFile.getFileURL(for: localType, with: fileName).path
    return fileManager.isReadableFile(atPath: filePath)
  }
  
  
  func checkIfExistsInS3(for fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    let objRequest = AWSS3HeadObjectRequest()!
    objRequest.bucket = Constants.S3BucketKey
    objRequest.key = fileName
    let task = s3Handler.headObject(objRequest)
    task.continueWith() { (task:AWSTask<AWSS3HeadObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
        if error.domain == AWSS3ErrorDomain {  // TODO: - Please make sure there are no silent fall through case. It can cause missing callback, then the whole app will f'ck up. Currently there is no time-out catch mechanism. If all our code works correctly, and the lower layer guarentees 1 response for every request, time-out at a level as high as our app shouldn't need one
          // didnt find the object
          callback?(ErrorCode.awsS3FileDoesntExistError)
          return nil
        }
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
  
  
  // MARK: - Public Instance Functions  
  init(withState operationState: FoodieObject.OperationStates) {
    foodieObject = FoodieObject(withState: operationState)
  }

  
  func retrieve(from localType: FoodieLocalType, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    CCLog.debug("Retrieve \(fileName) from \(localType.rawValue)")
    FoodieFile.manager.retrieve(from: localType, with: fileName, withBlock: callback)
  }
  
  
  func retrieveFromServerToLocal(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    CCLog.debug("Retrieve \(fileName) from S3 to Local Cache")
    FoodieFile.manager.retrieveFromS3(to: .cache, with: fileName, withBlock: callback)  // For now, would only ever retrieve from Server to Cache. Never to Draft
  }
  
  
  func retrieveFromServerToBuffer(withBlock callback: FoodieObject.RetrievedObjectBlock?) {
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
  
  
  func save(buffer: Data, to localType: FoodieLocalType, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Save Buffer as \(fileName) to \(localType.rawValue)")
      FoodieFile.manager.save(to: localType, from: buffer, with: fileName, withBlock: callback)
    } else {
      CCLog.debug("File \(fileName) already exist. Skipping Save")
      callback?(nil)
    }
  }

  
  func move(url: URL, to localType: FoodieLocalType, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Move to \(localType.rawValue) as \(fileName) from \(url.absoluteString)")
      FoodieFile.manager.moveFile(from: url, to: localType, with: fileName, withBlock: callback)
    } else {
      CCLog.debug("File \(fileName) already exist. Skipping Move")
      callback?(nil)
    }
  }
  
  
  func saveToServer(from localType: FoodieLocalType, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("FoodieS3Object has no foodieFileName")
    }
    
    FoodieFile.manager.checkIfExistsInS3(for: fileName) { error in
      if let error = error as? FoodieFile.ErrorCode {
        switch error {
        case .awsS3FileDoesntExistError:
          CCLog.debug("File \(fileName) does not exist on S3. Saving from \(localType.rawValue)")
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
  
  
  func delete(from localType: FoodieLocalType, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    if FoodieFile.manager.checkIfExists(in: localType, for: fileName) {
      CCLog.debug("Delete \(fileName) from \(localType.rawValue)")
      FoodieFile.manager.delete(from: localType, with: fileName, withBlock: callback)
    } else {
      CCLog.debug("File \(fileName) already not found from \(localType). Skipping Delete")
      callback?(nil)
    }
  }
  
  
  func deleteFromServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
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
  
  
  func deleteFromLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
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
