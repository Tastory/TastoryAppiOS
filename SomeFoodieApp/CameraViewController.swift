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

class CameraViewController: SwiftyCamViewController, SwiftyCamViewControllerDelegate {

  // MARK: - Private Constants
  struct Defaults {
    static let animateInDuration: CFTimeInterval = 0.7
    static let cameraButtonOnDuration: CFTimeInterval = 0.2
    static let cameraButtonOffDuration: CFTimeInterval = 0.2
  }
  
  
  // MARK: - Private Variables
  private var crossLayer = CameraCrossLayer()
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var captureButton: CameraButton?
  @IBOutlet weak var exitButton: ExitButton?
  @IBOutlet weak var tapRecognizer: UITapGestureRecognizer?
  
  
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

  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {

    super.viewDidLoad()
    cameraDelegate = self
    
    if let captureButton = captureButton {
      view.bringSubview(toFront: captureButton)
      #if !TARGET_INTERFACE_BUILDER
        captureButton.delegate = self
      #endif
    }
    
    if let exitButton = exitButton {
      view.bringSubview(toFront: exitButton)
    }
    
    if let tapRecognizer = tapRecognizer {
      tapRecognizer.delegate = self
    }
    
    PHPhotoLibrary.requestAuthorization { status in
      
      switch status {
      case .authorized:
        break
      case .denied:
        fallthrough
      default:
        let message = NSLocalizedString("SomeFoodieApp doesn't have permission to access your Photo Album",
                                        comment: "Alert message when the user has denied access to the photo album")
        let alertController = UIAlertController(title: "SomeFoodieApp", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                style: .cancel,
                                                handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                style: .default) { action in
          if #available(iOS 10.0, *) {
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
          } else if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.shared.openURL(appSettings)
          }
        })
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
        print("DEBUG_ERROR: CameraViewController.prepare - Expected sender to be of type UIImage")
        return
      }
      
      guard let mIVC = segue.destination as? MarkupImageViewController else {
        print("DEBUG_ERROR: CameraViewController.prepare - Expected segue.destiantion to be of type MarkupImageViewController")
        return
      }
      
      mIVC.previewPhoto = photo
      
    } else if segue.identifier == "toVideoMarkup" {
      
      guard let video = sender as? URL else {
        print("DEBUG_ERROR: CameraViewController.prepare - Expected sender to be of type URL")
        return
      }
      
      guard let mVVC = segue.destination as? MarkupVideoViewController else {
        print("DEBUG_ERROR: CameraViewController.prepare - Expected segue.destination to be of type MarkupVideoViewController")
        return
      }
      
      mVVC.videoURL = video
    }
    
//    else if segue.identifier == "unwindToMap" {
//      // Do nothing for now
//    }
//      
//    else {
//      print("DEBUG_ERROR: CameraViewController.prepare - No matching segue identifier")
//      fatalError("No matching segue identifier")
//    }
  }
  

  // MARK: - Swiftycam Delagates
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
    // Called when takePhoto() is called or if a SwiftyCamButton initiates a tap gesture
    // Returns a UIImage captured from the current session
    print("DEBUG_PRINT: didTakePhoto") // TODO: Make photos brighter too
    UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
    performSegue(withIdentifier: "toPhotoMarkup", sender: photo)
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when startVideoRecording() is called
    // Called if a SwiftyCamButton begins a long press gesture
    print("DEBUG_PRINT: didBeginRecordingVideo")
    // TODO: Make Videos Brighter?
    captureButton?.startRecording()
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when stopVideoRecording() is called
    // Called if a SwiftyCamButton ends a long press gesture
    print("DEBUG_PRINT: didFinishRecordingVideo")
    captureButton?.stopRecording()
    captureButton?.buttonReleased()
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
    // Called when stopVideoRecording() is called and the video is finished processing
    // Returns a URL in the temporary directory where video is stored
    print("DEBUG_PRINT: didFinishProcessVideoAt")
    
    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.absoluteString) {
      UISaveVideoAtPathToSavedPhotosAlbum(url.absoluteString, nil, nil, nil)
    } else {
      print("DEBUG_ERROR: CameraViewController.swiftyCam(didFinishProcesVideoAt) - received invalid URL for local filesystem")
    }
    
    performSegue(withIdentifier: "toVideoMarkup", sender: url)
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
    // Called when a user initiates a tap gesture on the preview layer
    // Will only be called if tapToFocus = true
    // Returns a CGPoint of the tap location on the preview layer
    print("DEBUG_PRINT: didFocusAtPoint")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
    // Called when a user initiates a pinch gesture on the preview layer
    // Will only be called if pinchToZoomn = true
    // Returns a CGFloat of the current zoom level
    print("DEBUG_PRINT: didChangeZoomLevel")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
    // Called when user switches between cameras
    // Returns current camera selection
    print("DEBUG_PRINT: didSwitchCameras")
  }
  
  
  // MARK: - UIGestureRecognizer Delegates
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}
