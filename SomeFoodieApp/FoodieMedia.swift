//
//  FoodieMedia.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-05-08.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import AWSCore
import AWSCognito
import AWSS3

import Foundation

/*
 AWS Developer Identity class for authenticating with AWS Cognito
 
 
class AWSDeveloperIdentity : AWSCognitoCredentialsProviderHelper {
    override func token() -> AWSTask<NSString> {
        //Write code to call your backend:
        //pass username/password to backend or some sort of token to authenticate user, if successful,
        //from backend call getOpenIdTokenForDeveloperIdentity with logins map containing "your.provider.name":"enduser.username"
        //return the identity id and token to client
        //You can use AWSTaskCompletionSource to do this asynchronously
        
        // Set the identity id and return the token
        self.identityId = "us-west-2:dabdd18d-a121-47b8-9b0a-3fa5a0525e11"
        return AWSTask(result: "eyJraWQiOiJ1cy13ZXN0LTIxIiwidHlwIjoiSldTIiwiYWxnIjoiUlM1MTIifQ.eyJzdWIiOiJ1cy13ZXN0LTI6ZGFiZGQxOGQtYTEyMS00N2I4LTliMGEtM2ZhNWEwNTI1ZTExIiwiYXVkIjoidXMtd2VzdC0yOjE0MGZhYzIxLTYyY2ItNDdmMS1hNWMxLTYzYmE4ODZmYzIzNCIsImFtciI6WyJhdXRoZW50aWNhdGVkIiwic29tZWZvb2RpZS5zM3dyaXRlciIsInNvbWVmb29kaWUuczN3cml0ZXI6dXMtd2VzdC0yOjE0MGZhYzIxLTYyY2ItNDdmMS1hNWMxLTYzYmE4ODZmYzIzNDpzcGVjYyJdLCJpc3MiOiJodHRwczovL2NvZ25pdG8taWRlbnRpdHkuYW1hem9uYXdzLmNvbSIsImV4cCI6MTQ5NDcwMjA1OSwiaWF0IjoxNDk0NzAxMTU5fQ.fF6c3QdDxsHmdzz2dJyyI1bALjR5fhqkNJqBTFOnXDNQqLFAwJ-e17tjxdWO6crV3CLPyUBitjN1U8JGpdBANoOfsdpTRu7RAY12BdkxQ7Rt1bA7chNfoWWozjGDnUAMOczDAg2iC-kqdBaQJkBPCIBZmbbPWVs7dvvzThJAlRxoUMeQZ6TXr7jzpOihDOzakdKGeXv0iVonbbrBrYpP-LiJ6CwXv7rmyXI7iWgKmxUKvUtuMwZ2av9Csz07dCrFL2aYrtqLxA-zLbM3Lila7O21QGbpDjMdN8kFRKKcumuAwTHbevR2wh2q9XJ3p4NLjAGA3C1ZN1K3G0AIzDGMjg")
    }
}*/

class FoodieMedia {
    
    let s3Handler: AWSS3
    let BUCKET_KEY = "foodilicious"
    let DOCUMENT_FOLDER_URL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
    let fileManager: FileManager
    
    
    let transferManager: AWSS3TransferManager
    
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
    
    func saveFileLocally(moment: FoodieMoment)
    {
        DispatchQueue.global(qos: .utility).async {
            
            let mediaURL = URL.init(string: moment.media!)!
            var destURL = self.DOCUMENT_FOLDER_URL
            destURL.appendPathComponent(mediaURL.lastPathComponent)
            
            let checSTR = destURL.absoluteString
            do{
                try self.fileManager.moveItem(at: mediaURL, to: destURL)
            }catch
            {
                DebugPrint.assert("Failed to save media file to local Documents folder")
            }
            
            // update URL reference 
            moment.setMedia(URL: destURL)
            self.upload(fileURL: destURL)
        }
    }
    
    func deleteFileLocally(fileName: String)
    {
       do {
            try fileManager.removeItem(atPath: "\(DOCUMENT_FOLDER_URL.path)/\(fileName)")
        }
        catch {
            print("couln't remove ")
        }
    }
    
    func checkIfFileExistsS3(fileName : String){
        
        let objRequest = AWSS3HeadObjectRequest()!
        objRequest.bucket = BUCKET_KEY
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
    
    
    
    func deleteFromS3(fileName : String)
    {
        
        let delRequest = AWSS3DeleteObjectRequest()!
        
        delRequest.bucket = BUCKET_KEY
        delRequest.key = fileName
        s3Handler.deleteObject(delRequest)
    }
    
    func cancelAllS3Transfer()
    {
        transferManager.cancelAll()
    }
    
    func download(fileName: String)
    {
        let downloadFileURL = DOCUMENT_FOLDER_URL.appendingPathComponent(fileName)

        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest?.bucket = BUCKET_KEY
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
    
    
    func upload(fileURL: URL){
        
        //let resourceName = "ElephantSeals.mov"
        //let name = (resourceName as NSString).deletingPathExtension
        //let type = (resourceName as NSString).pathExtension
        //let mediaURL = Bundle.main.url(forResource: name, withExtension: type)!
        
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest?.bucket = "foodilicious"
        uploadRequest?.key = fileURL.lastPathComponent
        uploadRequest?.body = fileURL
        
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
            // TODO might be useful to store in parse for tracking the version
            let versionId = task.result?.versionId
            print("Upload complete for: \(String(describing: uploadRequest?.key))")
            return nil
        })
    }
class FoodieMedia: NSObject /* S3 Object */ {
  
  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()

  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
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
    if let earlyReturnStatus = foodieObject.saveStateTransition(to: location) {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlyReturnStatus, nil) }
    }
  }
  
  func saveToLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteFromLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
}
