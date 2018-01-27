//
//  CameraViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//
//  This is a reusable Camera View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  -
//  Output - Will always export taken photo or video to MarkupViewController and push it to the top of the View Controller stack
//

import UIKit
import Photos
import MobileCoreServices
import SwiftyCam
import TLPhotoPicker


protocol CameraReturnDelegate: class {
  func captureComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?)
}


class CameraViewController: SwiftyCamViewController, UINavigationControllerDelegate {  // View needs to comply to certain protocols going forward?
  
  // MARK: - Global Constants
  struct GlobalConstants {
    static let animateInDuration: CFTimeInterval = 0.7  // Duration for things to animate in when the camera view initially loads
    static let cameraButtonOnDuration: CFTimeInterval = 0.2  // Duration for animation when the capture button is pressed
    static let cameraButtonOffDuration: CFTimeInterval = 0.2  // Duration for animation when the cpature button is depressed
  }
  
  
  // MARK: Public Instance Variables
  weak var cameraReturnDelegate: CameraReturnDelegate?
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
  fileprivate var activitySpinner: ActivitySpinner? = nil
  
  
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
      configure.muteAudio = true
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
      let alertController = UIAlertController(title: "Tastory",
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
      let alertController = UIAlertController(title: "Tastory",
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
    
    activitySpinner = ActivitySpinner(addTo: view)
    
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
    
    // If user opt'ed for Save Originals To Library. Double check for corresponding Permissions
    if let currentUser = FoodieUser.current, currentUser.saveOriginalsToLibrary {
      
      // Double check for Photo Library Request Authorization
      switch PHPhotoLibrary.authorizationStatus() {
      case .authorized:
        break
        
      case .restricted:
        currentUser.saveOriginalsToLibrary = false
        AlertDialog.present(from: self, title: "Photos Restricted", message: "Photo access have been restricted by the operating system. Save media to library is not possible") { _ in
          CCLog.warning("Photo Library Authorization Restricted")
        }
        
      case .denied:
        currentUser.saveOriginalsToLibrary = false
        let appName = Bundle.main.displayName ?? "Tastory"
        let urlDialog = AlertDialog.createUrlDialog(title: "Photo Library Inaccessible",
                                                    message: "Please go to Settings > Privacy > Photos to allow \(appName) to access your Photo Library, then try again",
          url: UIApplicationOpenSettingsURLString)
        
        self.present(urlDialog, animated: true, completion: nil)
        
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization { status in
          switch status {
          case .authorized:
            break
            
          case .restricted:
            AlertDialog.present(from: self, title: "Photos Restricted", message: "Photo access have been restricted by the operating system. Save media to library is not possible") { _ in
              CCLog.warning("Photo Library Authorization Restricted")
            }
            fallthrough
            
          default:
            currentUser.saveOriginalsToLibrary = false
          }
        }
      }
      
      if !currentUser.saveOriginalsToLibrary {
        currentUser.saveDigest(to: .both, type: .cache) { error in
          if let error = error {
            CCLog.warning("User save for denied Library Authorization failed - \(error.localizedDescription)")
          }
        }
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
    
    Analytics.logCameraPhotoEvent(userID: FoodieUser.current?.username ?? "nil")
    
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
    if let currentUser = FoodieUser.current, currentUser.saveOriginalsToLibrary {
      UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    let mediaObject = FoodieMedia(for: FoodieFileObject.newPhotoFileName(), localType: .draft, mediaType: .photo)
    mediaObject.imageFormatter(image: image)
    
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
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
      if let currentUser = FoodieUser.current, currentUser.saveOriginalsToLibrary {
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
      }
      
      let fileName = FoodieFileObject.newVideoFileName()
      let mediaObject = FoodieMedia(for: fileName, localType: .draft, mediaType: .video)
      mediaObject.setVideo(toLocal: url)
      
      guard let activitySpinner = activitySpinner else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Activity Spinner is not initialized")
        }
        return
      }
      
      activitySpinner.apply()
      
      // Analytics
      let avUrlAsset = AVURLAsset(url: url)
      let duration = CMTimeGetSeconds(avUrlAsset.duration)
      Analytics.logCameraVideoEvent(userID: FoodieUser.current?.username ?? "nil", duration: Double(duration))
      
      mediaObject.localVideoTranscode(to: FoodieFileObject.getFileURL(for: .draft, with: fileName), thru: FoodieFileObject.getRandomTempFileURL()) { error in
        if let error = error {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("AVExportPlayer export asynchronously failed with error \(error.localizedDescription)")
          }
          return
          
        } else if FoodieFileObject.checkIfExists(for: fileName, in: .draft) {
          mediaObject.setVideo(toLocal: FoodieFileObject.getFileURL(for: .draft, with: fileName))
          
          DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Compose", bundle: nil)
            guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
              }
              return
            }
            viewController.mediaObj = mediaObject
            viewController.mediaLocation = self.captureLocation
            viewController.markupReturnDelegate = self
            viewController.addToExistingStoryOnly = self.addToExistingStoryOnly
            activitySpinner.remove()
            self.present(viewController, animated: true)
          }
          
          // Get rid of the old temporary File
          do {
            try FileManager.default.removeItem(at: url)
          } catch {
            CCLog.warning("Delete of Swift Cam temp file \(url.absoluteString) failed - \(error.localizedDescription)")
          }
          
        } else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("AVExportPlayer exported video but file doesn't exists in \(FoodieFileObject.getFileURL(for: .draft, with: fileName))")
          }
          return
        }
      }
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.mediaObj = mediaObj
    viewController.markupReturnDelegate = self
    viewController.addToExistingStoryOnly = addToExistingStoryOnly
    self.present(viewController, animated: true)
  }
  
  func convertToMedia(from tlphAsset: TLPHAsset, isLimitDuration: Bool, withBlock callback: @escaping (FoodieMedia?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard tlphAsset.phAsset != nil else {
        CCLog.assert("Failed to unwrap phAsset from TLPHAsset")
        return
      }
      
      switch tlphAsset.type {
        case .photo, .livePhoto:
          let photoName = FoodieFileObject.newPhotoFileName()
          let mediaObject = FoodieMedia(for: photoName, localType: .draft, mediaType: .photo)
          if(tlphAsset.fullResolutionImage == nil) {
            // icloud image
            tlphAsset.cloudImageDownload(progressBlock: { (completion) in
              CCLog.verbose("downloading \(photoName) completed at \(completion * 100)%")
            }, completionBlock: { (uiImage) in

              guard let uiImage = uiImage else {
                CCLog.assert("Failed to unwrap uiImage downloaded from iCloud")
                return
              }
              mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(uiImage, CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
              callback(mediaObject)
            })

          } else {

            mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(tlphAsset.fullResolutionImage!, CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
            callback(mediaObject)
          }

        case .video:

          let videoName = FoodieFileObject.newVideoFileName()
          tlphAsset.tempCopyMediaFile(progressBlock: { (completion) in
            CCLog.verbose("downloading \(videoName) at \(completion * 100)%")
          }) { (url, mimeType) in
              let mediaObject = FoodieMedia(for: videoName, localType: .draft, mediaType: .video)
              mediaObject.setVideo(toLocal: url)
              callback(mediaObject)
            }
      }
    }
  }
  
  
  func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) {

    self.activitySpinner?.apply()

    if withTLPHAssets.count < 0 {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("No asset returned from TLPHAsset")
      }
    }
    
    outstandingConvertQueue.async {
      self.moments = Array.init(repeatElement(nil, count: withTLPHAssets.count))
      
      for tlphAsset in withTLPHAssets {
        self.outstandingConvertOperations += 1
        self.convertToMedia(from: tlphAsset, isLimitDuration: withTLPHAssets.count > 1) { (foodieMedia) in
          
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
  }
  
  
  private func processMoments() {

    self.activitySpinner?.remove()

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
          ConfirmationDialog.displayStorySelection(to: self, newStoryHandler: { (uiaction) in
            ConfirmationDialog.showStoryDiscardDialog(to: self, withBlock: {
              FoodieStory.cleanUpDraft() { error in
                
                if let error = error {
                  AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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
    } else {
      if(moments.count == 1) {
        guard let moment = moments[0] else {
          CCLog.assert("Unwrapped nil moment")
          return
        }
        
        guard let mediaObj = moment.media else {
          CCLog.assert("Unwrapped nil moment")
          return
        }
        
        let storyboard = UIStoryboard(name: "Compose", bundle: nil)
        let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VideoTrimmerViewController") as! VideoTrimmerViewController
        viewController.avAsset = AVURLAsset(url: (mediaObj.localVideoUrl)!)
        viewController.delegate = self
        DispatchQueue.main.async {
          self.present(viewController, animated: true, completion: nil)
        }
      }
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
      
      guard let movieUrl = info[UIImagePickerControllerMediaURL] as? URL else {
        CCLog.assert("video URL is not returned from image picker")
        return
      }
      
      // Analytics
      let avUrlAsset = AVURLAsset(url: movieUrl)
      if let avUrlTrack = avUrlAsset.tracks(withMediaType: .video).first {
        let mediaSize = avUrlTrack.naturalSize.applying(avUrlTrack.preferredTransform)
        let aspectRatio = mediaSize.width / mediaSize.height
        let duration = CMTimeGetSeconds(avUrlAsset.duration)
        Analytics.logPickerVideoEvent(userID: FoodieUser.current?.username ?? "nil",
                                      width: abs(Double(mediaSize.width)),
                                      aspectRatio: abs(Double(aspectRatio)),
                                      duration: duration)
      }
      
      // Go into Video Clip trimming if the Video can be edited
      if UIVideoEditorController.canEditVideo(atPath: movieUrl.relativePath) {
        
        let storyboard = UIStoryboard(name: "Compose", bundle: nil)
        let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VideoTrimmerViewController") as! VideoTrimmerViewController
        viewController.avAsset = AVURLAsset(url: movieUrl)
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
        return
      }
      
      CCLog.warning("Video at URL \(movieUrl) cannot be edited")
      mediaObject = FoodieMedia(for: movieUrl.lastPathComponent, localType: .draft, mediaType: .video)
      mediaObject.setVideo(toLocal: movieUrl)
      
    case String(kUTTypeImage):
      
      mediaName = FoodieFileObject.newPhotoFileName()
      
      guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
        CCLog.assert("UIImage is not returned from image picker")
        return
      }
      
      // Analytics
      Analytics.logPickerPhotoEvent(userID: FoodieUser.current?.username ?? "nil", width: Double(image.size.width), aspectRatio: Double(image.size.width/image.size.height))
      
      mediaObject = FoodieMedia(for: mediaName, localType: .draft, mediaType: .photo)
      mediaObject.imageFormatter(image: image)
      
    default:
      AlertDialog.present(from: self, title: "Media Select Error", message: "Media picked is not a Video nor a Photo") { [unowned self] _ in
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
    mediaObject.setVideo(toLocal: movieUrl)
    
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
    AlertDialog.present(from: self, title: "Video Edit Failed", message: error.localizedDescription) { _ in
      CCLog.assert("Video Editing Failed with Error - \(error.localizedDescription)")
    }
  }
}



extension CameraViewController: VideoTrimmerDelegate {
  func videoTrimmed(from startTime: CMTime, to endTime: CMTime, url assetURLString: String) {
    
    guard let activitySpinner = activitySpinner else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Activity Spinner is not initialized")
      }
      return
    }
    
    guard let url = URL(string: assetURLString) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Invalid Asset URL String")
      }
      return
    }
    
    activitySpinner.apply()
    
    let fileName = url.lastPathComponent
    let mediaObject = FoodieMedia(for: fileName, localType: .draft, mediaType: .video)
    mediaObject.setVideo(toLocal: url)
    let asset = AVAsset(url: url)

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) else {
      return
    }
    exportSession.outputURL = FoodieFileObject.getRandomTempFileURL()
    exportSession.outputFileType = AVFileType.mov
    exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
    exportSession.exportAsynchronously{
      switch exportSession.status {
      case .completed:

        //copy over
        guard let outputURL = exportSession.outputURL else {
          CCLog.fatal("outputURL = nil. Cannot switch AVPlayer backing to Local File")
        }

        let localURL = FoodieFileObject.getFileURL(for: .draft, with: fileName)
        CCLog.verbose("Copying AVExport Output from \(outputURL.absoluteString) to \(localURL.absoluteString)")

        do {
          try FileManager.default.copyItem(at: outputURL, to: localURL)
        } catch CocoaError.fileWriteFileExists {
          CCLog.warning("Trying to copy AVExport from Tmp to Local for file \(localURL.absoluteString) already exist")
        } catch {
          CCLog.assert("Failed to copy from \(outputURL.absoluteString) to \(localURL.absoluteString)")
        }

        activitySpinner.remove()

        DispatchQueue.main.async {
          let storyboard = UIStoryboard(name: "Compose", bundle: nil)
          let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
          mediaObject.setVideo(toLocal: localURL)
          viewController.mediaObj = mediaObject
          viewController.markupReturnDelegate = self
          viewController.addToExistingStoryOnly = self.addToExistingStoryOnly
          self.present(viewController, animated: true)
        }
      case .failed, .cancelled:
        if let error = exportSession.error {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("AVExportPlayer export asynchronously failed with error \(error.localizedDescription)")
          }
          return
        }

      default: break
      }
    }
  }
}

