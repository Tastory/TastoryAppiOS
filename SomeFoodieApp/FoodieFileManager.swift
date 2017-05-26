//
//  FoodieFileManager.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-17.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import AWSCore
import AWSCognito
import AWSS3
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
    case fileManagerSaveLocalFailed
    
    var errorDescription: String? {
      switch self {
      case .fileManagerMoveItemLocalFailed:
        return NSLocalizedString("FileManager.moveItem failed", comment: "Error description for an exception error code")
      case .fileManagerSaveLocalFailed:
        return NSLocalizedString("Data.write failed", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Constants
  struct Constants {
    static let S3BucketKey = "foodilicious"
    static let DocumentFolderUrl = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
  }
  
  
  // MARK: - Public Static Variables
  static var manager: FoodieFile!
  static var localBufferDirectory: String!
  
  
  // MARK: - Private Instance Variables
  private let s3Handler: AWSS3
  private let fileManager: FileManager
  private let transferManager: AWSS3TransferManager
  
  
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
      let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAIAFK5EC3O6535MDQ", secretKey: "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")
      let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest1, credentialsProvider:credentialsProvider)
      AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    s3Handler = AWSS3.default()
    transferManager = AWSS3TransferManager.default()
    fileManager = FileManager.default
  }
  
  
  func saveDataToLocal(buffer: Data, fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DispatchQueue.global(qos: .utility).async {
      do {
        try buffer.write(to: Constants.DocumentFolderUrl.appendingPathComponent("\(fileName)"))
      } catch {
        DebugPrint.assert("Failed to write media data to local Documents folder \(error.localizedDescription)")
        callback?(false, ErrorCode.fileManagerSaveLocalFailed)
      }
    }
  }
  
  
  func moveFileFromUrlToLocal(url: URL, fileName: String, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DispatchQueue.global(qos: .utility).async {
      do {
        try self.fileManager.moveItem(atPath: url.path, toPath: "\(Constants.DocumentFolderUrl.path)/\(fileName)")
      } catch {
        DebugPrint.assert("Failed to move media file to local Documents folder \(error.localizedDescription)")
        callback?(false, ErrorCode.fileManagerMoveItemLocalFailed)
      }
    }
  }
  
  
  func saveLocalFileToS3(fileName: String) {
    
    let uploadRequest = AWSS3TransferManagerUploadRequest()
    uploadRequest?.bucket = Constants.S3BucketKey
    uploadRequest?.key = fileName
    //uploadRequest?.body = fileURL
    
    transferManager.upload((uploadRequest)!).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AnyObject>) -> Any? in
      
      if let error = task.error as NSError? {
        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
          switch code {
          case .cancelled, .paused:
            break
          default:
            print("Error uploading: \(String(describing: uploadRequest?.key)) Error: \(error)")
          }
        } else {
          print("Error uploading: \(String(describing: uploadRequest?.key)) Error: \(error)")
        }
        return nil
      }
      // TODO: might be useful to store in parse for tracking the version
      print("Upload complete for: \(String(describing: uploadRequest?.key))")
      return nil
    })
  }
  
  
  func deleteFileFromLocal(fileName: String) {
    do {
      try fileManager.removeItem(atPath: "\(Constants.DocumentFolderUrl.path)/\(fileName)")
    } catch {
      print("Failed to delete media file from local Documents foler \(error.localizedDescription)")
    }
  }
  
  
  func deleteFileFromS3(fileName: String) {
    let delRequest = AWSS3DeleteObjectRequest()!
    
    delRequest.bucket = Constants.S3BucketKey
    delRequest.key = fileName
    s3Handler.deleteObject(delRequest)
  }

  
  func checkIfFileExistsS3(fileName: String){
    
    let objRequest = AWSS3HeadObjectRequest()!
    objRequest.bucket = Constants.S3BucketKey
    objRequest.key = fileName
    let task = s3Handler.headObject(objRequest)
    task.continueWith(block:{ (task:AWSTask<AWSS3HeadObjectOutput>) -> Any? in
      if let error = task.error as NSError? {
        if error.domain == AWSS3ErrorDomain {
          // didnt find the object
          return nil
        }
      }
      // found object
      return nil
    })
  }
  
  
  func cancelAllS3Transfer()
  {
    transferManager.cancelAll()
  }
  
  
  func download(fileName: String)
  {
    let downloadFileURL = Constants.DocumentFolderUrl.appendingPathComponent(fileName)
    
    let downloadRequest = AWSS3TransferManagerDownloadRequest()
    downloadRequest?.bucket = Constants.S3BucketKey
    downloadRequest?.key = fileName
    downloadRequest?.downloadingFileURL = downloadFileURL
    
    transferManager.download((downloadRequest)!).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AnyObject>) -> Any? in
      
      if let error = task.error as NSError? {
        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
          switch code {
          case .cancelled, .paused:
            break
          default:
            print("Error Downloading: \(String(describing: downloadRequest?.key)) Error: \(error)")
          }
        } else {
          print("Error Downloading: \(String(describing: downloadRequest?.key)) Error: \(error)")
        }
        return nil
      }
      
      _ = task.result
      print("Download complete for: \(String(describing: downloadRequest?.key))")
      return nil
    })
  }
}


class FoodieS3Object {

  // MARK: - Public Instance Variable
  var foodieFileName: String?
  
  
  // MARK: - Public Instance Functions
  func saveDataBufferToLocal(buffer: Data, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      DebugPrint.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.saveDataToLocal(buffer: buffer, fileName: fileName, withBlock: callback)
  }

  
  func saveTmpUrlToLocal(url: URL, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    guard let fileName = foodieFileName else {
      DebugPrint.fatal("Unexpected. FoodieS3Object has no foodieFileName")
    }
    FoodieFile.manager.moveFileFromUrlToLocal(url: url, fileName: fileName, withBlock: callback)
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
  }
}
