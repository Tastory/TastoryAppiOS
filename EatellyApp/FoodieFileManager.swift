//
//  FoodieFileManager.swift
//  SomeFoodieApp
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
    static let S3BucketKey = "eatelly-live"
    static let CloudFrontUrl = URL(string: "https://ddlng06pr7edc.cloudfront.net/")!
    static let DocumentFolderUrl = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
    static let AwsRetryCount = FoodieGlobal.Constants.DefaultServerRequestRetryCount
    static let AwsRetryDelay = FoodieGlobal.Constants.DefaultServerRequestRetryDelay
  }
  
  
  // MARK: - Public Static Variables
  static var manager: FoodieFile!
  static var localBufferDirectory: String!
  
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
  
  
  static func getLocalFileURL(from fileName: String) -> URL {
    return Constants.DocumentFolderUrl.appendingPathComponent(fileName)
  }
  
  
  // MARK: - Public Instance Functions
  init(){
    
    /*
     Authenticating with AWS Cognito
     let devAuth = AWSDeveloperIdentity(regionType: AWSRegionType.USWest2, identityPoolId: "us-west-2:140fac21-62cb-47f1-a5c1-63ba886fc234", useEnhancedFlow: true, identityProviderManager:nil)
     let credentialsProvider = AWSCognitoCredentialsProvider(regionType: AWSRegionType.USWest2, identityProvider:devAuth)
     let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider:credentialsProvider)
     AWSServiceManager.default().defaultServiceConfiguration = configuration
     */
    
    if(!(AWSServiceManager.default().defaultServiceConfiguration != nil))
    {
      let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAIIG7G45RQHBX3JGQ", secretKey: "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")
      //let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAJOCP23CCCK7MP7XQ", secretKey: "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")
      let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider:credentialsProvider)
      AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    s3Handler = AWSS3.default()
    fileManager = FileManager.default
    transferManager = AWSS3TransferManager.default()
    downloadsSession = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
  }
  
  
  func retrieveFromLocalToBufffer(fileName: String, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {
      let buffer: Data?
      do {
        buffer = try Data(contentsOf: Constants.DocumentFolderUrl.appendingPathComponent("\(fileName)"))
      } catch {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
          CCLog.debug("No file '\(fileName) in local directory")
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
  
  
  #if false
  // S3 Transfer Manager based implementation
  func retrieveFromServerToLocal(fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?)
  {
    guard let downloadRequest = AWSS3TransferManagerDownloadRequest() else {
      CCLog.assert("AWSS3TransferManagerDownloadRequest() returned nil")
      callback?(nil, ErrorCode.awsS3TransferManagerDownloadRequestNil)
      return
    }
    
    let localFileUrl = Constants.DocumentFolderUrl.appendingPathComponent(fileName)
    
    downloadRequest.bucket = Constants.S3BucketKey
    downloadRequest.key = fileName
    downloadRequest.downloadingFileURL = localFileUrl
  
    // Let's time the download!
    let downloadStartTime = PrecisionTime.now()
    
    transferManager.download(downloadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task:AWSTask<AnyObject>) -> Any? in
      
      let downloadEndTime = PrecisionTime.now()
      
      if let error = task.error as NSError? {
        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
          switch code {
          case .cancelled:
            CCLog.debug("AWS Transfer Download with Key \(downloadRequest.key!)")
            callback?(nil, ErrorCode.awsS3TransferDownloadCancelled)
          case .paused:
            // Victor to look into what is the right action for Pause
            CCLog.fatal("Pause is not well understood and not currently supported. Pulling a Fatal condition for now")
          default:
            CCLog.warning("AWS Transfer Download with Key \(String(describing: downloadRequest.key)) resulted in Error: \(error)")
            callback?(nil, ErrorCode.awsS3TransferDownloadUnknownError)
          }
        } else {
          CCLog.warning("AWS Transfer Download with Key \(String(describing: downloadRequest.key)) resulted in Error: \(error)")
          callback?(nil, ErrorCode.awsS3TransferDownloadUnknownError)
        }
        return nil
      }
      
      // We are in success-land!
      let timeDifference = downloadEndTime - downloadStartTime
      var timeBaseInfo = mach_timebase_info_data_t()
      mach_timebase_info(&timeBaseInfo)
      let timeDifferenceNs = timeDifference * UInt64(timeBaseInfo.numer) / UInt64(timeBaseInfo.denom)
      let timeDifferenceS = Float(timeDifferenceNs)/1000000000
      
      do {
        let fileAttribute = try self.fileManager.attributesOfItem(atPath: localFileUrl.path)
        let fileSizeKb = Float(fileAttribute[FileAttributeKey.size] as! Int)/1000.0
        let avgDownloadSpeed = Float(fileSizeKb)/timeDifferenceS  // KB/s
      
        CCLog.verbose("Download of \(fileName) of size \(fileSizeKb/1000.0) MB took \(timeDifferenceS*1000.0) ms at \(avgDownloadSpeed) kB/s")
      } catch {
        CCLog.fatal("Obtaining file attribute failed. Error = \(error.localizedDescription)")
      }
      
      // TODO: might be useful to store in parse for tracking the version: _ = task.result
      CCLog.debug("AWS Transfer Download completed for Key \(downloadRequest.key!)")
      callback?(downloadRequest.key!, nil)
      return nil
    }
  }
  #else
  // Cloudfront based implementation
  func retrieveFromServerToLocal(fileName: String, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    let localFileURL = Constants.DocumentFolderUrl.appendingPathComponent(fileName)
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
  #endif
  
  
  func saveDataToLocal(buffer: Data, fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try buffer.write(to: Constants.DocumentFolderUrl.appendingPathComponent("\(fileName)"))
      } catch {
        CCLog.assert("Failed to write media data to local Documents folder \(error.localizedDescription)")
        callback?(false, ErrorCode.fileManagerSaveLocalFailed)
        return
      }
      // Save to Local completed successfully!!
      callback?(true, nil)
    }
  }
  
  
  func moveFileFromUrlToLocal(url: URL, fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.fileManager.moveItem(atPath: url.path, toPath: "\(Constants.DocumentFolderUrl.path)/\(fileName)")
      } catch {
        CCLog.assert("Failed to move media file to local Documents folder \(error.localizedDescription)")
        callback?(false, ErrorCode.fileManagerMoveItemLocalFailed)
        return
      }
      // Move local completed successfully!!
      callback?(true, nil)
    }
  }
  
  
  func saveLocalFileToS3(fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
      CCLog.assert("AWSS3TransferManagerUploadRequest() returned nil")
      callback?(false, ErrorCode.awsS3TransferManagerUploadRequestNil)
      return
    }
    uploadRequest.bucket = Constants.S3BucketKey
    uploadRequest.key = fileName
    uploadRequest.body = Constants.DocumentFolderUrl.appendingPathComponent("\(fileName)")
    
    // Victor, I don't realy understand this code. What is the return -> Any? for in the closure block?
    transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task:AWSTask<AnyObject>) -> Any? in
      
      if let error = task.error as NSError? {
        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
          switch code {
          case .cancelled:
            CCLog.debug("AWS Transfer Upload with Key \(uploadRequest.key!) cancelled")
            callback?(false, ErrorCode.awsS3TransferUploadCancelled)
          case .paused:
            // Victor, how is this supposed to work? If it's paused, then when does the resume come in? We need to do a callback once AWS SDK calls us back because there's a pending chain of FoodieObjects saves waiting on this callback. Unless AWS SDK will call us back again some time down the road when this resumes and completes? I am doubtful tho....?
            CCLog.fatal("Pause is not well understood and not currently supported. Pulling a Fatal condition for now")
          default:
            CCLog.warning("AWS Transfer Upload with Key \(String(describing: uploadRequest.key)) resulted in Error: \(error)")
            callback?(false, ErrorCode.awsS3TransferUploadUnknownError)
          }
        } else {
          CCLog.warning("AWS Transfer Upload with Key \(String(describing: uploadRequest.key)) resulted in Error: \(error)")
          callback?(false, ErrorCode.awsS3TransferUploadUnknownError)
        }
        return nil
      }
      // TODO: might be useful to store in parse for tracking the version
      CCLog.debug("AWS Transfer Upload completed for Key \(uploadRequest.key!)")
      callback?(true, nil)
      return nil
    }
  }
  
  
  func deleteFileFromLocal(fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    do {
      try fileManager.removeItem(atPath: "\(Constants.DocumentFolderUrl.path)/\(fileName)")
    } catch {
      print("Failed to delete media file from local Documents foler \(error.localizedDescription)")
      callback?(false, ErrorCode.fileManagerMoveItemLocalFailed)
    }
    // Delete local completed successfully!!
    callback?(true, nil)
  }


  func deleteFileFromS3(fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    let delRequest = AWSS3DeleteObjectRequest()!
    delRequest.bucket = Constants.S3BucketKey
    delRequest.key = fileName
    let deleteTask = s3Handler.deleteObject(delRequest)
    deleteTask.continueWith() { (task: AWSTask<AWSS3DeleteObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
          callback?(false,error)
      }
      // successfully deleted
      callback?(true, nil)
      return nil
    }
  }
  
  
  func checkIfFileExistsLocally(for fileName: String) -> Bool {
    let filePath = FoodieFile.getLocalFileURL(from: fileName).path
    return fileManager.isReadableFile(atPath: filePath)
  }
  
  
  func checkIfFileExistsS3(fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    let objRequest = AWSS3HeadObjectRequest()!
    objRequest.bucket = Constants.S3BucketKey
    objRequest.key = fileName
    let task = s3Handler.headObject(objRequest)
    task.continueWith() { (task:AWSTask<AWSS3HeadObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
        if error.domain == AWSS3ErrorDomain {  // TODO: - Please make sure there are no silent fall through case. It can cause missing callback, then the whole app will f'ck up. Currently there is no time-out catch mechanism. If all our code works correctly, and the lower layer guarentees 1 response for every request, time-out at a level as high as our app shouldn't need one
          // didnt find the object
          callback?(false, ErrorCode.awsS3FileDoesntExistError)
          return nil
        }
      }
      // found object
      callback?(true, nil)
      return nil
    }
  }
  
  func cancelAllS3Transfer()
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

  func retrieveFromLocalToBuffer(withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.retrieveFromLocalToBufffer(fileName: fileName, withBlock: callback)
  }
  
  
  func retrieveFromServerToLocal(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.retrieveFromServerToLocal(fileName: fileName, withBlock: callback)
  }
  
  
  func retrieveFromServerToBuffer(withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.retrieveFromServerToLocal(fileName: fileName) { (error) in
      if error == nil {
        FoodieFile.manager.retrieveFromLocalToBufffer(fileName: fileName, withBlock: callback)
      }
      else {
        callback?(nil, error)
      }
    }
  }
  
  
  func saveDataBufferToLocal(buffer: Data, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfFileExistsLocally(for: fileName) {
      FoodieFile.manager.saveDataToLocal(buffer: buffer, fileName: fileName, withBlock: callback)
    } else {
      callback?(true, nil)
    }
  }

  
  func saveTmpUrlToLocal(url: URL, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    // Check if the file already exist. If so just assume it's the right file
    if !FoodieFile.manager.checkIfFileExistsLocally(for: fileName) {
      FoodieFile.manager.moveFileFromUrlToLocal(url: url, fileName: fileName, withBlock: callback)
    } else {
      callback?(true, nil)
    }
  }
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.checkIfFileExistsS3(fileName: fileName) { (fileExists, error) in
      if let error = error as? FoodieFile.ErrorCode {
        switch error {
        case .awsS3FileDoesntExistError:
          break
        default:
          CCLog.warning("CheckIfFileExists on S3 for Save returned error - \(error.localizedDescription)")
          callback?(false, error)
          return
        }
      }
      if !fileExists {  // Save if file doesn't exist
        FoodieFile.manager.saveLocalFileToS3(fileName: fileName, withBlock: callback)
      } else {  // Assume already good and saved otherwise
        callback?(true, nil)
      }
    }
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    if (FoodieFile.manager.checkIfFileExistsLocally(for: fileName))
    {
      FoodieFile.manager.deleteFileFromLocal(fileName: fileName, withBlock: callback)
    } else {
      // file doesnt exists can let go of this error as if file was deleted successfully
      callback?(true, nil)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      CCLog.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    
    FoodieFile.manager.checkIfFileExistsS3(fileName: fileName) { (success, error) in
      if let error = error {
        CCLog.warning("CheckIfFileExists on S3 for Delete returned error - \(error.localizedDescription)")
      }
      if success {
        FoodieFile.manager.deleteFileFromS3(fileName: fileName, withBlock: callback)
      } else {
        // file doesnt exists can let go of this error as if file was deleted successfully 
        callback?(true, nil)
      }
    }
  }
  
  func getUniqueIdentifier() -> String {
    return foodieFileName!
  }
}
