//
//  CameraViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//
//  This is a reusable Camera View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  -
//  Output - Will always export taken photo or video to MarkupViewController and push it to the top of the View Controller stack
//

import UIKit
import Photos
import SwiftyCam


protocol CameraReturnDelegate {
  func captureComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?)
}


class CameraViewController: SwiftyCamViewController, UINavigationControllerDelegate {  // View needs to comply to certain protocols going forward?
  
  // MARK: - Global Constants
  struct GlobalConstants {
    static let animateInDuration: CFTimeInterval = 0.7  // Duration for things to animate in when the camera view initially loads
    static let cameraButtonOnDuration: CFTimeInterval = 0.2  // Duration for animation when the capture button is pressed
    static let cameraButtonOffDuration: CFTimeInterval = 0.2  // Duration for animation when the cpature button is depressed
  }
  
  
  // MARK: Public Instance Variables
  var cameraReturnDelegate: CameraReturnDelegate?
  
  
  // MARK: - Private Variables
  private var crossLayer = CameraCrossLayer()
  
  // MARK: - IBOutlets
  @IBOutlet weak var captureButton: CameraButton?
  @IBOutlet weak var exitButton: ExitButton?
  @IBOutlet weak var tapRecognizer: UITapGestureRecognizer?  // This is workaround to detect capture button's been released after a photo
  @IBOutlet weak var imagePicker: UIButton?
  
  // MARK: - IBActions

  @IBAction func launchImagePicker(_ sender: Any) {
    let imagePickerController = UIImagePickerController()
    imagePickerController.sourceType = .photoLibrary
    imagePickerController.delegate = self

    // var types = UIImagePickerController.availableMediaTypes(for: UIImagePickerControllerSourceType.photoLibrary)

    imagePickerController.mediaTypes = ["public.image", "public.movie"]

    self.present(imagePickerController, animated: true, completion: nil)
    
  }

  @IBAction func capturePressed(_ sender: CameraButton) {
    captureButton?.buttonPressed()
  }
  
  @IBAction func captureTapped(_ sender: UITapGestureRecognizer) {
    captureButton?.buttonReleased()
  }
  
  @IBAction func exitPressed(_ sender: UIButton) {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }
  
  // MARK: - Class Private Functions
  
  // Generic error dialog box to the user on internal errors
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Camera view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Camera view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for generic CameraView errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // MARK: - Reset the states of the Camera View
  private func resetAllStates() {
    
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    
    super.viewDidLoad()
    cameraDelegate = self

    if let imagePicker = imagePicker {
      view.bringSubview(toFront: imagePicker)
    }

    if let captureButton = captureButton {
      view.bringSubview(toFront: captureButton)
      captureButton.delegate = self
    }
    
    if let exitButton = exitButton {
      view.bringSubview(toFront: exitButton)
    }
    
    if let tapRecognizer = tapRecognizer {
      tapRecognizer.delegate = self
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
          DebugPrint.assert("UIApplicationOPenSettignsURLString ia an invalid URL String???")
          break
        }
        
        let alertController = UIAlertController(title: "Photo Library Inaccessible",
                                                titleComment: "Alert diaglogue title when user has denied access to the photo album",
                                                message: "Please go to Settings > Privacy > Photos to allow SomeFoodieApp to save to your photos",
                                                messageComment: "Alert dialog message when the user has denied access to the photo album",
                                                preferredStyle: .alert)
        
        alertController.addAlertAction(title: "Settings",
                                       comment: "Alert diaglogue button to open Settings, hoping user will allow access to photo album",
                                       style: .default) { action in UIApplication.shared.open(url, options: [:]) }
        
        self.present(alertController, animated: true, completion: nil)
      }
    }
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    DebugPrint.log("CameraViewController.didReceiveMemoryWarning")
  }
  
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
} // CameraViewController class definision


extension CameraViewController: SwiftyCamViewControllerDelegate {
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake image: UIImage) {
    // Called when takePhoto() is called or if a SwiftyCamButton initiates a tap gesture
    // Returns a UIImage captured from the current session
    DebugPrint.userAction("didTakePhoto") // TODO: Make photos brighter too
    
    // Also save photo to Photo Album.
    // TODO: Allow user to configure whether save to Photo Album also
    // TODO: Create error alert dialog box if this save fails.
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

    let mediaObject = FoodieMedia(withState: .objectModified, fileName: FoodieFile.newPhotoFileName(), type: .photo)
    mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(image, CGFloat(FoodieConstants.jpegCompressionQuality))
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
    viewController.mediaObj = mediaObject
    viewController.markupReturnDelegate = self
    self.present(viewController, animated: true)
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when startVideoRecording() is called
    // Called if a SwiftyCamButton begins a long press gesture
    DebugPrint.userAction("didBeginRecordingVideo")
    // TODO: Make Videos Brighter?
    captureButton?.startRecording()
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when stopVideoRecording() is called
    // Called if a SwiftyCamButton ends a long press gesture
    DebugPrint.userAction("didFinishRecordingVideo")
    captureButton?.stopRecording()
    captureButton?.buttonReleased()
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
    // Called when stopVideoRecording() is called and the video is finished processing
    // Returns a URL in the temporary directory where video is stored
    DebugPrint.log("didFinishProcessVideoAt")
    
    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
      // Also save video to Photo Album.
      // TODO: Allow user to configure whether save to Photo Album also
      // TODO: Create error alert dialog box if this save fails.
      UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
      
      let mediaObject = FoodieMedia(withState: .objectModified, fileName: FoodieFile.newVideoFileName(), type: .video)
      mediaObject.videoLocalBufferUrl = url
      
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
      viewController.mediaObj = mediaObject
      viewController.markupReturnDelegate = self
      self.present(viewController, animated: true)
      
    } else {
      self.internalErrorDialog()
      DebugPrint.assert("Received invalid URL for local filesystem")
      captureButton?.buttonReset()
    }
  }
  
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
    // Called when a user initiates a tap gesture on the preview layer
    // Will only be called if tapToFocus = true
    // Returns a CGPoint of the tap location on the preview layer
    DebugPrint.userAction("didFocusAtPoint")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
    // Called when a user initiates a pinch gesture on the preview layer
    // Will only be called if pinchToZoomn = true
    // Returns a CGFloat of the current zoom level
    DebugPrint.userAction("didChangeZoomLevel")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
    // Called when user switches between cameras
    // Returns current camera selection
    DebugPrint.userAction("didSwitchCameras")
  }
  
  
  // MARK: - UIGestureRecognizer Delegates
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}


extension CameraViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?) {
    guard let delegate = cameraReturnDelegate else {
      internalErrorDialog()
      DebugPrint.assert("Unexpected, cameraReturnDelegate = nil")
      return
    }
    delegate.captureComplete(markedupMoment: markedupMoment, suggestedJournal: suggestedJournal)
  }
}

extension CameraViewController: UIImagePickerControllerDelegate {
  public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
    let mediaType = info[UIImagePickerControllerMediaType] as! String
    //let imageName = url.lastPathComponent
    picker.dismiss(animated:true, completion: nil)

    var mediaObject: FoodieMedia
    var mediaName: String

    if("public.movie" == mediaType)
    {
      let movieUrl = info[UIImagePickerControllerMediaURL] as! NSURL
      mediaObject = FoodieMedia(withState: .objectModified, fileName: (movieUrl.lastPathComponent)!, type: .video)
      mediaObject.videoLocalBufferUrl = URL(fileURLWithPath: (movieUrl.relativePath)!)
    } else {
      mediaName = FoodieFile.newPhotoFileName()
      let image = info[UIImagePickerControllerOriginalImage] as! UIImage
      mediaObject = FoodieMedia(withState: .objectModified, fileName: mediaName, type: .photo)
      mediaObject.imageMemoryBuffer = UIImageJPEGRepresentation(image, CGFloat(FoodieConstants.jpegCompressionQuality))
    }

    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
    viewController.mediaObj = mediaObject
    viewController.markupReturnDelegate = self
    self.present(viewController, animated: true)


    /* Image



    */



    /*
     let image = info[UIImagePickerControllerOriginalImage] as! UIImage
     let data = UIImagePNGRepresentation(image)
     data.writeToFile(localPath, atomically: true)

     let imageData = NSData(contentsOfFile: localPath)!
     let photoURL = NSURL(fileURLWithPath: localPath)
     let imageWithData = UIImage(data: imageData)!
     */
       //self.dismiss(animated: true, completion: nil)
  }
}





