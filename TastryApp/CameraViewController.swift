//
//  CameraViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastry. All rights reserved.
//
//  This is a reusable Camera View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  -
//  Output - Will always export taken photo or video to MarkupViewController and push it to the top of the View Controller stack
//

import UIKit
import Photos
import SwiftyCam
import MobileCoreServices
import TLPhotoPicker


protocol CameraReturnDelegate {
  func captureComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?)
}


class CameraViewController: SwiftyCamViewController, UINavigationControllerDelegate {  // View needs to comply to certain protocols going forward?

  // MARK: - Global Constants
  struct GlobalConstants {
    static let animateInDuration: CFTimeInterval = 0.7  // Duration for things to animate in when the camera view initially loads
    static let cameraButtonOnDuration: CFTimeInterval = 0.2  // Duration for animation when the capture button is pressed
    static let cameraButtonOffDuration: CFTimeInterval = 0.2  // Duration for animation when the cpature button is depressed
  }
  
  
  // MARK: - Constants
  struct Constants {
    fileprivate static let ImageShortEdgeMax: CGFloat = 1080
    fileprivate static let CropAspectRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
  }
  
  
  // MARK: Public Instance Variables
  var cameraReturnDelegate: CameraReturnDelegate?
  var addToExistingStoryOnly = false

  
  // MARK: - Private Instance Variables
  fileprivate var crossLayer = CameraCrossLayer()
  fileprivate var captureLocation: CLLocation? = nil
  fileprivate var captureLocationError: Error? = nil
  fileprivate var locationWatcher: LocationWatch.Context? = nil
  fileprivate var outstandingConvertOperations = 0
  fileprivate var outstandingConvertQueue = DispatchQueue(label: "Outstanding Convert Queue", qos: .userInitiated)
  fileprivate var moments: [FoodieMoment?] = []
  fileprivate var enableMultiPicker = false


  // MARK: - IBOutlets
  @IBOutlet weak var captureButton: CameraButton?
  @IBOutlet weak var exitButton: ExitButton?
  @IBOutlet weak var tapRecognizer: UITapGestureRecognizer?  // This is workaround to detect capture button's been released after a photo
  @IBOutlet weak var pickerButton: ImagePickerButton!

  // MARK: - IBActions

  @IBAction func switchSelfieMode(_ sender: Any) {
    switchCamera()
  }
  
  @IBAction func launchImagePicker(_ sender: Any) {

    if(enableMultiPicker) {
      let photoPickerController = TLPhotosPickerViewController()
      var configure = TLPhotosPickerConfigure()
      configure.usedCameraButton = false
      configure.allowedLivePhotos = false
      configure.maxSelectedAssets = 10
      photoPickerController.delegate = self
      photoPickerController.configure = configure
      self.present(photoPickerController, animated: false, completion: nil)
    }
    else {
      let imagePickerController = UIImagePickerController()
      imagePickerController.sourceType = .photoLibrary
      imagePickerController.mediaTypes = [kUTTypeImage, kUTTypeMovie] as [String]
      imagePickerController.videoQuality = .typeIFrame960x540
      imagePickerController.videoMaximumDuration = TimeInterval(15.0)
      imagePickerController.allowsEditing = false  // Hand the editing to an explicit Editor
      imagePickerController.delegate = self
      self.present(imagePickerController, animated: true, completion: nil)
    }
  }

  @IBAction func capturePressed(_ sender: CameraButton) {
    CCLog.info("User Action - CameraViewController.capturePressed()")
    captureButton?.buttonPressed()
  }
  
  @IBAction func captureTapped(_ sender: UITapGestureRecognizer) {
    CCLog.info("User Action - CameraViewController.captureTapped()")
    captureButton?.buttonReleased()
  }
  
  @IBAction func exitPressed(_ sender: UIButton) {
    CCLog.info("User Action - CameraViewController.exitPressed()")
    dismiss(animated: true, completion: nil)
  }
  
  // MARK: - Private Instance Functions
  
  // Generic error dialog box to the user on internal errors
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Camera view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Camera view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for generic CameraView errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func locationErrorDialog(message: String, comment: String) {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Camera View location error occured",
                                              message: message,
                                              messageComment: comment,
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for location related Camera View errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    
    super.viewDidLoad()
    
    // Swifty Cam Setup
    cameraDelegate = self
    doubleTapCameraSwitch = true
    videoQuality = .resolution1920x1080  // .high is 16x9, but .medium is 4x3
    maximumVideoDuration = 15.0
    
    if let pickerButton = pickerButton {
      view.bringSubview(toFront: pickerButton)
    }

    if let captureButton = captureButton {
      view.bringSubview(toFront: captureButton)
      captureButton.delegate = self
      captureButton.isEnabled = false  // Disable this button until SwiftyCam's AVCaptureSession isRunning == true
    }
    
    if let exitButton = exitButton {
      view.bringSubview(toFront: exitButton)
    }
    
    if let tapRecognizer = tapRecognizer {
      tapRecognizer.delegate = self
    }
    
    // Listen to notification of when SwiftyCam's AVCaptureSession isRunning == true
    NotificationCenter.default.addObserver(forName: .AVCaptureSessionDidStartRunning, object: nil, queue: OperationQueue.main) { _ in
      self.captureButton?.cameraSessionIsReady()
      NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionDidStartRunning, object: nil)
    }
    
    // Request permission from user to access the Photo Album up front
    PHPhotoLibrary.requestAuthorization { status in
      switch status {
      case .authorized:
        break
      case .denied:
        fallthrough
      default:
        // Permission was denied before. Ask for permission again
        guard let url = URL(string: UIApplicationOpenSettingsURLString) else {
          CCLog.assert("UIApplicationOPenSettignsURLString ia an invalid URL String???")
          break
        }
        
        let alertController = UIAlertController(title: "Photo Library Inaccessible",
                                                titleComment: "Alert diaglogue title when user has denied access to the photo album",
                                                message: "Please go to Settings > Privacy > Photos to allow TastryApp to save to your photos",
                                                messageComment: "Alert dialog message when the user has denied access to the photo album",
                                                preferredStyle: .alert)
        
        alertController.addAlertAction(title: "Settings",
                                       comment: "Alert diaglogue button to open Settings, hoping user will allow access to photo album",
                                       style: .default) { action in UIApplication.shared.open(url, options: [:]) }
        
        self.present(alertController, animated: true, completion: nil)
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    captureLocation = nil
    captureLocationError = nil
    locationWatcher = LocationWatch.global.start() { (location, error) in
      if let error = error {
        CCLog.debug("Cannot obtain Location information for Camera capture")
        self.captureLocationError = error
      }
      
      if let location = location {
        self.captureLocation = location
      }
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    locationWatcher?.stop()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
  
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
} // CameraViewController class definision


extension CameraViewController: SwiftyCamViewControllerDelegate {
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake image: UIImage) {
    // Called when takePhoto() is called or if a SwiftyCamButton initiates a tap gesture
    // Returns a UIImage captured from the current session
    CCLog.info("User Action - didTakePhoto") // TODO: Make photos brighter too
    
//  Metadata/EXIF data Extraction Example
//   1. By the time SwiftyCam have made it from a CGDataProvider -> CGImage -> UIImage and we convert it back to a CGDataProvider, it seems that everything is stripped
//   2. Even putting the code to extract metadata into SwiftyCam, GPS data does not seem to be part of the data set.
//
//    if let cgImage = image.cgImage {
//      if let cgProvider = cgImage.dataProvider {
//        if let source = CGImageSourceCreateWithDataProvider(cgProvider, nil) {
//          if let type = CGImageSourceGetType(source) {
//            print("type: \(type)")
//          }
//          
//          if let properties = CGImageSourceCopyProperties(source, nil) {
//            print("properties - \(properties)")
//          }
//          
//          let count = CGImageSourceGetCount(source)
//          print("count: \(count)")
//          
//          for index in 0..<count {
//            if let metaData = CGImageSourceCopyMetadataAtIndex(source, index, nil) {
//              print("all metaData[\(index)]: \(metaData)")
//              
//              let typeId = CGImageMetadataGetTypeID()
//              print("metadata typeId[\(index)]: \(typeId)")
//              
//              
//              if let tags = CGImageMetadataCopyTags(metaData) as? [CGImageMetadataTag] {
//                
//                print("number of tags - \(tags.count)")
//                
//                for tag in tags {
//                  
//                  let tagType = CGImageMetadataTagGetTypeID()
//                  if let name = CGImageMetadataTagCopyName(tag) {
//                    print("name: \(name)")
//                  }
//                  if let value = CGImageMetadataTagCopyValue(tag) {
//                    print("value: \(value)")
//                  }
//                  if let prefix = CGImageMetadataTagCopyPrefix(tag) {
//                    print("prefix: \(prefix)")
//                  }
//                  if let namespace = CGImageMetadataTagCopyNamespace(tag) {
//                    print("namespace: \(namespace)")
//                  }
//                  if let qualifiers = CGImageMetadataTagCopyQualifiers(tag) {
//                    print("qualifiers: \(qualifiers)")
//                  }
//                  print("-------")
//                }
//              }
//            }
//            
//            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) {
//              print("properties[\(index)]: \(properties)")
//            }
//          }
//        }
//      }
//    }
    
    // Also save photo to Photo Album.
    // TODO: Allow user to configure whether save to Photo Album also
    // TODO: Create error alert dialog box if this save fails.
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

    let mediaObject = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
    imageFormatter(mediaObject, image: image)

    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.mediaObj = mediaObject
    viewController.mediaLocation = captureLocation
    viewController.markupReturnDelegate = self
    viewController.addToExistingStoryOnly = addToExistingStoryOnly
    self.present(viewController, animated: true)
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when startVideoRecording() is called
    // Called if a SwiftyCamButton begins a long press gesture
    CCLog.info("User Action - didBeginRecordingVideo")
    // TODO: Make Videos Brighter?
    captureButton?.startRecording()
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when stopVideoRecording() is called
    // Called if a SwiftyCamButton ends a long press gesture
    CCLog.info("User Action - didFinishRecordingVideo")
    captureButton?.stopRecording()
    captureButton?.buttonReleased()
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
    // Called when stopVideoRecording() is called and the video is finished processing
    // Returns a URL in the temporary directory where video is stored
    CCLog.debug("didFinishProcessVideoAt")
    
    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
      // Also save video to Photo Album.
      // TODO: Allow user to configure whether save to Photo Album also
      // TODO: Create error alert dialog box if this save fails.
      UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
      
      let mediaObject = FoodieMedia(for: FoodieFileObject.newVideoFileName(), localType: .draft, mediaType: .video)
      let avExportPlayer = AVExportPlayer()
      avExportPlayer.initAVPlayer(from: url)
      mediaObject.videoExportPlayer = avExportPlayer
      
      let storyboard = UIStoryboard(name: "Compose", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
        }
        return
      }
      viewController.mediaObj = mediaObject
      viewController.mediaLocation = captureLocation
      viewController.markupReturnDelegate = self
      viewController.addToExistingStoryOnly = addToExistingStoryOnly
      self.present(viewController, animated: true)
      
    } else {
      self.internalErrorDialog()
      CCLog.assert("Received invalid URL for local filesystem")
      captureButton?.buttonReset()
    }
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
    // Called when a user initiates a tap gesture on the preview layer
    // Will only be called if tapToFocus = true
    // Returns a CGPoint of the tap location on the preview layer
    CCLog.info("User Action - didFocusAtPoint")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
    // Called when a user initiates a pinch gesture on the preview layer
    // Will only be called if pinchToZoomn = true
    // Returns a CGFloat of the current zoom level
    CCLog.info("User Action - didChangeZoomLevel")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
    // Called when user switches between cameras
    // Returns current camera selection
    CCLog.info("User Action - didSwitchCameras")
  }
  
  
  // MARK: - UIGestureRecognizer Delegates
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}


extension CameraViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    guard let delegate = cameraReturnDelegate else {
      internalErrorDialog()
      CCLog.assert("Unexpected, cameraReturnDelegate = nil")
      return
    }
    delegate.captureComplete(markedupMoments: markedupMoments, suggestedStory: suggestedStory)
  }
}

extension CameraViewController: TLPhotosPickerViewControllerDelegate {

  private func displayMarkUpController(mediaObj: FoodieMedia) {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.mediaObj = mediaObj
    viewController.markupReturnDelegate = self
    viewController.addToExistingStoryOnly = addToExistingStoryOnly
    self.present(viewController, animated: true)
  }

  func convertToMedia(from tlphAsset: TLPHAsset, withBlock callback: @escaping (FoodieMedia?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard tlphAsset.phAsset != nil else {
        CCLog.assert("Failed to unwrap phAsset from TLPHAsset")
        return
      }

      var mediaObject: FoodieMedia
      switch(tlphAsset.type)
      {
      case .photo:

        guard let uiImage = tlphAsset.fullResolutionImage else {
          CCLog.assert("failed to unwrap ui image from TLPH Asset")
          return
        }

        var mediaObject: FoodieMedia
        mediaObject = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
        mediaObject.imageMemoryBuffer =
          UIImageJPEGRepresentation(
            uiImage,
            CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
        callback(mediaObject)

      case .video:

        let videoName = FoodieFileObject.newVideoFileName()
        mediaObject = FoodieMedia(for: videoName, localType: .draft, mediaType: .video)
        tlphAsset.phAsset?.copyMediaFile(withName: videoName) { (url, error) in

          if let error = error {
            CCLog.fatal("Error occured when trying to copy video from photo albumn to tmp folder - \(error.localizedDescription)")
          }
          
          guard let url = url else {
            CCLog.fatal("No URL returend from copyMediaFile()")
          }
          
          let avExportPlayer = AVExportPlayer()
          avExportPlayer.initAVPlayer(from: url)
          mediaObject.videoExportPlayer = avExportPlayer
          callback(mediaObject)
        }

      default:
        AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { action in
          CCLog.fatal("Media returned from Image Picker is neither a Photo nor a Video")
        }
      }
    }
  }

  func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) {
    if withTLPHAssets.count < 0 {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("No asset returned from TLPHAsset")
      }
    }

    outstandingConvertQueue.async {
      self.moments = Array.init(repeatElement(nil, count: withTLPHAssets.count))
      
      for tlphAsset in withTLPHAssets {
        self.outstandingConvertOperations += 1
        self.convertToMedia(from: tlphAsset) { (foodieMedia) in

          guard let foodieMedia = foodieMedia else {
            CCLog.assert("Failed to convert tlphAsset to FoodieMedia as foodieMedia is nil")
            return
          }
          
          let moment = FoodieMoment(foodieMedia: foodieMedia)
          self.moments[(tlphAsset.selectedOrder - 1)] = moment

          self.outstandingConvertQueue.async {
            self.outstandingConvertOperations -= 1
            if self.outstandingConvertOperations == 0 { self.processMoments() }
          }
        }
      }
    }
  }

  func dismissComplete() {
    // to display all the buttons properly in markup this code must be in this function otherwise
    // the buttons will be hidden
    if(moments.count == 1) {
      guard let moment = moments[0] else {
        CCLog.assert("Unwrapped nil moment")
        return
      }

      guard let mediaObj = moment.media else {
        CCLog.assert("Unwrapped nil moment")
        return
      }
      self.displayMarkUpController(mediaObj: mediaObj)
    }
  }

  private func processMoments() {
    if(moments.count > 1)
    {
      var selectedMoments: [FoodieMoment] = []
      for moment in moments {

        guard let unwrappedMoment = moment else {
          CCLog.assert("moment is nil")
          return
        }

        selectedMoments.append(unwrappedMoment)
      }

      var workingStory: FoodieStory
      if(FoodieStory.currentStory == nil)
      {
        workingStory =  FoodieStory.newCurrent()
        self.cameraReturnDelegate?.captureComplete(markedupMoments: selectedMoments, suggestedStory: workingStory)
      }
      else
      {
        workingStory = FoodieStory.currentStory!

        if(addToExistingStoryOnly) {
          DispatchQueue.main.async {
            self.cameraReturnDelegate?.captureComplete(markedupMoments: selectedMoments, suggestedStory: workingStory)
          }
        } else {
          StorySelector.displayStorySelection(to: self, newStoryHandler: { (uiaction) in
            StorySelector.showStoryDiscardDialog(to: self, withBlock: {
              FoodieStory.cleanUpDraft() { error in

                if let error = error {
                  AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
                    CCLog.assert("Error when cleaning up story from draft- \(error.localizedDescription)")
                  }
                  return
                }
                self.cameraReturnDelegate?.captureComplete(markedupMoments: selectedMoments, suggestedStory: FoodieStory.newCurrent())
              }
            })
          }, addToCurrentHandler: { (uiaction) in
            self.cameraReturnDelegate?.captureComplete(markedupMoments: selectedMoments, suggestedStory: workingStory)
          })
        }
      }
    }
  }

  
  // TODO: - CameraVC shouldn't need to know the innards of Image Manipulation? This should be a FoodieMedia instance function that CameraVC can call on?
  private func imageFormatter(_ media:FoodieMedia, image bufferImage: UIImage) {

    var bufferImage = bufferImage

    guard let fileName = media.foodieFileName else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("the file name is missing from this foodieMedia")
      }
      return
    }

    let fileUrl = FoodieFileObject.getFileURL(for: .draft, with: fileName) as CFURL
    let destination = CGImageDestinationCreateWithURL(fileUrl, kUTTypeJPEG, 1, nil)!
    let jfifProperties = [kCGImagePropertyJFIFIsProgressive: kCFBooleanTrue] as NSDictionary
    let properties = [
      kCGImageDestinationLossyCompressionQuality: 0.5,
      kCGImagePropertyJFIFDictionary: jfifProperties
      ] as NSDictionary

    var imageSize = bufferImage.size

    guard var cgImage = bufferImage.cgImage else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("cgImage is nil from bufferImage")
      }
      return
    }

    // TODO: - Crop Aspect Ratio should be an input argument parameter. We shouldn't put in crop assumptions in here
    let cropAspectRatio = Constants.CropAspectRatio
    let currentAspectRatio = imageSize.width/imageSize.height
    
    // Photo wider than it should be
    if currentAspectRatio > cropAspectRatio {
      let cropWidth = imageSize.height * cropAspectRatio
      if bufferImage.imageOrientation == .right {
        // Portrait photo wider than it should be
        guard let cropImage = cgImage.cropping(to: CGRect(x: 0, y:(((imageSize.width/2) - (cropWidth/2))) , width: imageSize.height, height: cropWidth)) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.assert("cropImage is nil after cropping")
          }
          return
        }
        bufferImage = UIImage(cgImage: cropImage, scale: 1.0, orientation: bufferImage.imageOrientation)
        cgImage = cropImage
        
      } else {
        // defualt imageOrientation is .up
        // Landscape photo wider than it should be
        guard let cropImage = cgImage.cropping(to: CGRect(x: ((imageSize.width/2) - (cropWidth/2)) , y: 0, width: cropWidth, height: imageSize.height)) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.assert("cropImage is nil after cropping")
          }
          return
        }
        bufferImage = UIImage(cgImage: cropImage, scale: 1.0, orientation: bufferImage.imageOrientation)
        cgImage = cropImage
      }
      imageSize = bufferImage.size
      
    // Photo taller than it should be
    } else if currentAspectRatio < cropAspectRatio {
      let cropHeight = imageSize.width / cropAspectRatio
      if bufferImage.imageOrientation == .right {
        // Portrait photo taller than it should be
        guard let cropImage = cgImage.cropping(to: CGRect(x: (((imageSize.height/2) - cropHeight/2)), y: 0, width: cropHeight, height: imageSize.width)) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.assert("cropImage is nil after cropping")
          }
          return
        }
        bufferImage = UIImage(cgImage: cropImage, scale: 1.0, orientation: bufferImage.imageOrientation)
        cgImage = cropImage
        
      } else {
        // defualt imageOrientation is .up
        // Landscape photo taller than it should be
        guard let cropImage = cgImage.cropping(to: CGRect(x: 0, y: (((imageSize.height/2) - cropHeight/2)), width: imageSize.width, height: cropHeight)) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.assert("cropImage is nil after cropping")
          }
          return
        }
        bufferImage = UIImage(cgImage: cropImage, scale: 1.0, orientation: bufferImage.imageOrientation)
        cgImage = cropImage
      }
      imageSize = bufferImage.size
    }

    // TODO: - Downsize max should be an input argument parameter. We shouldn't put in resolution presumptions in here
    let shortEdgeMax = Constants.ImageShortEdgeMax
    var newSize = imageSize
    
    if imageSize.height < imageSize.width, imageSize.height > shortEdgeMax {
      let scaleRatio = shortEdgeMax/imageSize.height
      newSize = CGSize(width: imageSize.width*scaleRatio, height: shortEdgeMax)
    }
    else if imageSize.width < imageSize.height, imageSize.width > shortEdgeMax  {
      let scaleRatio = shortEdgeMax/imageSize.width
      newSize = CGSize(width: shortEdgeMax, height: imageSize.height*scaleRatio)
    }
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, bufferImage.scale);
    bufferImage.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
    bufferImage = UIGraphicsGetImageFromCurrentImageContext()!

    guard let context = UIGraphicsGetCurrentContext() else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
         CCLog.assert("Failed to get UIGraphic current context")
      }
      return
    }
    context.translateBy(x: 0, y: 0)
    UIGraphicsEndImageContext()

    if(bufferImage.cgImage == nil) {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("cgImage is nil from bufferImage")
      }
      return
    }
    cgImage = bufferImage.cgImage!

    CGImageDestinationAddImage(destination, cgImage, properties)
    if(!CGImageDestinationFinalize(destination)) {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("Failed to format the image")
      }
      return
    }

    do {
      try media.imageMemoryBuffer = Data(contentsOf: fileUrl as URL)
    } catch {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("Failed to get image data from the file url")
      }
      return
    }
  }
}

extension CameraViewController: UIImagePickerControllerDelegate {
  public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){

    guard let mediaType = info[UIImagePickerControllerMediaType] as? String else {
      CCLog.assert("Media type is expected after selection from image picker")
      return
    }

    picker.dismiss(animated:true, completion: nil)

    var mediaObject: FoodieMedia
    var mediaName: String

    switch mediaType {

    case String(kUTTypeMovie):

      guard let movieUrl = info[UIImagePickerControllerMediaURL] as? NSURL else {
        CCLog.assert("video URL is not returned from image picker")
        return
      }

      guard let moviePath = movieUrl.relativePath else {
        CCLog.assert("video URL \(movieUrl.absoluteString ?? "") is missing relative path")
        return
      }
  
      // Go into Video Clip trimming if the Video can be edited
      if UIVideoEditorController.canEditVideo(atPath: moviePath) {

        let storyboard = UIStoryboard(name: "Compose", bundle: nil)
        let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VideoTrimmerViewController") as! VideoTrimmerViewController
        viewController.avAsset = AVURLAsset(url: movieUrl as URL)
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
        return

      } else {
        CCLog.warning("Video at path \(moviePath) cannot be edited")
      }
      
      guard let movieName = movieUrl.lastPathComponent else {
        CCLog.assert("video URL is missing movie name")
        return
      }
      
      mediaObject = FoodieMedia(for: movieName, localType: .draft, mediaType: .video)
      let avExportPlayer = AVExportPlayer()
      avExportPlayer.initAVPlayer(from: URL(fileURLWithPath: moviePath))
      mediaObject.videoExportPlayer = avExportPlayer
      
      
    case String(kUTTypeImage):
      
      mediaName = FoodieFileObject.newPhotoFileName()
      
      guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
        CCLog.assert("UIImage is not returned from image picker")
        return
      }

      mediaObject = FoodieMedia(for: mediaName, localType: .draft, mediaType: .photo)
      imageFormatter(mediaObject, image: image)

    default:
      AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { action in
        CCLog.assert("Media returned from Image Picker is neither a Photo nor a Video")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }

    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
    viewController.mediaObj = mediaObject
    viewController.markupReturnDelegate = self
    viewController.addToExistingStoryOnly = addToExistingStoryOnly
    self.present(viewController, animated: true)
  }
}


extension CameraViewController: UIVideoEditorControllerDelegate {
  func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
    
    let movieUrl = URL(fileURLWithPath: editedVideoPath, isDirectory: false)
    let movieName = movieUrl.lastPathComponent
    
    let mediaObject = FoodieMedia(for: movieName, localType: .draft, mediaType: .video)
    let avExportPlayer = AVExportPlayer()
    avExportPlayer.initAVPlayer(from: movieUrl)
    mediaObject.videoExportPlayer = avExportPlayer
    
    editor.dismiss(animated: true) {
      let storyboard = UIStoryboard(name: "Compose", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
      viewController.mediaObj = mediaObject
      viewController.markupReturnDelegate = self
      viewController.addToExistingStoryOnly = self.addToExistingStoryOnly
      
      self.present(viewController, animated: true)
    }
  }
  
  func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
    CCLog.info("User cancelled Video Editor")
  }
  
  func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
    AlertDialog.present(from: self, title: "Video Edit Failed", message: error.localizedDescription) { action in
      CCLog.assert("Video Editing Failed with Error - \(error.localizedDescription)")
    }
  }
}

extension CameraViewController: VideoTrimmerDelegate {
  func videoTrimmed(from startTime: CMTime, to endTime: CMTime, url assetURL: String) {

      let url = URL(fileURLWithPath: assetURL)
      let fileName = url.lastPathComponent
      let mediaObject = FoodieMedia(for: fileName, localType: .draft, mediaType: .video)
      let avExportPlayer = AVExportPlayer()
      let activitySpinner = ActivitySpinner(addTo: self.view)

      activitySpinner.apply()
      avExportPlayer.initAVPlayer(from: url)
      mediaObject.videoExportPlayer = avExportPlayer
      avExportPlayer.exportAsync(to: FoodieFileObject.getFileURL(for: .draft, with: fileName), thru: FoodieFileObject.getRandomTempFileURL(),duration:
        CMTimeRangeMake(startTime, endTime)) { error in

        activitySpinner.remove()
        if let error = error {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("AVExportPlayer export asynchronously failed with error \(error.localizedDescription)")
          }
          return
        }

        let storyboard = UIStoryboard(name: "Compose", bundle: nil)
        let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
        viewController.mediaObj = mediaObject
        viewController.markupReturnDelegate = self
        viewController.addToExistingStoryOnly = self.addToExistingStoryOnly
        self.present(viewController, animated: true)

      }
  }
}

