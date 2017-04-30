//
//  CameraViewController.swift
//  
//
//  Created by Howard Lee on 2017-03-26.
//
//

import UIKit
import Photos
import SwiftyCam

class CameraViewController: SwiftyCamViewController {  // View needs to comply to certain protocols going forward?

  // MARK: - Global Constants
  struct GlobalConstants {
    static let animateInDuration: CFTimeInterval = 0.7  // Duration for things to animate in when the camera view initially loads
    static let cameraButtonOnDuration: CFTimeInterval = 0.2  // Duration for animation when the capture button is pressed
    static let cameraButtonOffDuration: CFTimeInterval = 0.2  // Duration for animation when the cpature button is depressed
  }
  
  
  // MARK: - Private Variables
  private var crossLayer = CameraCrossLayer()
  
   
  // MARK: - IBOutlets
  @IBOutlet weak var captureButton: CameraButton?
  @IBOutlet weak var exitButton: ExitButton?
  @IBOutlet weak var tapRecognizer: UITapGestureRecognizer?  // This is workaround to detect capture button's been released after a photo
  
  
  // MARK: - IBActions
  @IBAction func unwindToCamera(segue: UIStoryboardSegue) {
    // Nothing for now
  }
  
  @IBAction func capturePressed(_ sender: CameraButton) {
    captureButton?.buttonPressed()
  }
  
  @IBAction func captureTapped(_ sender: UITapGestureRecognizer) {
    captureButton?.buttonReleased()
  }

  
  // MARK: - Class Private Functions

  // Generic error dialogue box to the user on internal errors
  fileprivate func internalErrorDialog() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when a Camera view internal error occured",
                                            message: "An internal error has occured. Please try again",
                                            messageComment: "Alert dialogue message when a Camera view internal error occured",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK", comment: "Button in alert dialogue box for generic CameraView errors", style: .cancel)
    self.present(alertController, animated: true, completion: nil)
  }
  
  
  // MARK: - Reset the states of the Camera View
  private func resetAllStates() {
    
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {

    super.viewDidLoad()
    cameraDelegate = self
    
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
                                                messageComment: "Alert dialogue message when the user has denied access to the photo album",
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
    // Dispose of any resources that can be recreated.
  }
    

  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    
    if segue.identifier == "toPhotoMarkup" {
      
      guard let photo = sender as? UIImage else {
        internalErrorDialog()
        DebugPrint.assert("Expected sender to be of type UIImage")
        captureButton?.buttonReset()
        return
      }
      
      guard let mIVC = segue.destination as? MarkupViewController else {
        internalErrorDialog()
        DebugPrint.assert("Expected segue.destination to be of type MarkupViewController")
        captureButton?.buttonReset()
        return
      }
      
      mIVC.previewPhoto = photo
      
    } else if segue.identifier == "toVideoMarkup" {
      
      guard let video = sender as? URL else {
        internalErrorDialog()
        DebugPrint.assert("Expected sender to be of type URL")
        captureButton?.buttonReset()
        return
      }
      
      guard let mVVC = segue.destination as? MarkupVideoViewController else {
        internalErrorDialog()
        DebugPrint.assert("Expected segue.destination to be of type MarkupVideoViewController")
        captureButton?.buttonReset()
        return
      }
      
      mVVC.videoURL = video
    }
    
//    else if segue.identifier == "unwindToMap" {
//      // Do nothing for now
//    }
//      
//    else {
//      DebugPrint.assert("No matching segue identifier")
//    }
  }
} // CameraViewController class definision


extension CameraViewController: SwiftyCamViewControllerDelegate {
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
    // Called when takePhoto() is called or if a SwiftyCamButton initiates a tap gesture
    // Returns a UIImage captured from the current session
    DebugPrint.userAction("didTakePhoto") // TODO: Make photos brighter too
    UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
    performSegue(withIdentifier: "toPhotoMarkup", sender: photo)
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
    
    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.absoluteString) {
      UISaveVideoAtPathToSavedPhotosAlbum(url.absoluteString, nil, nil, nil)
      performSegue(withIdentifier: "toVideoMarkup", sender: url)
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
