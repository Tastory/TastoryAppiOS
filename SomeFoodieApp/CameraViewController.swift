//
//  CameraViewController.swift
//  
//
//  Created by Howard Lee on 2017-03-26.
//
//

import UIKit
import SwiftyCam

class CameraViewController: SwiftyCamViewController, SwiftyCamViewControllerDelegate {

  struct Defaults {
    static let animateInDuration: CFTimeInterval = 0.7
    static let cameraButtonOnDuration: CFTimeInterval = 0.2
    static let cameraButtonOffDuration: CFTimeInterval = 0.2
  }
  
  private var crossLayer = CameraCrossLayer()
  
  @IBOutlet weak var captureButton: CameraButton?
  @IBOutlet weak var exitButton: ExitButton?
  
  @IBAction func capturePressed(_ sender: CameraButton) {
    captureButton?.buttonPressed()
  }
  
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
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
    

  /*
  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
  }
  */

  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
    // Called when takePhoto() is called or if a SwiftyCamButton initiates a tap gesture
    // Returns a UIImage captured from the current session
    print("DEBUG_PRINT: didTakePhoto")
    captureButton?.buttonReleased()
    
    
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when startVideoRecording() is called
    // Called if a SwiftyCamButton begins a long press gesture
    print("didBeginRecordingVideo")
    captureButton?.startRecording()
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
    // Called when stopVideoRecording() is called
    // Called if a SwiftyCamButton ends a long press gesture
    print("didFinishRecordingVideo")
    captureButton?.stopRecording()
    captureButton?.buttonReleased()
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
    // Called when stopVideoRecording() is called and the video is finished processing
    // Returns a URL in the temporary directory where video is stored
    print("didFinishProcessVideoAt")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
    // Called when a user initiates a tap gesture on the preview layer
    // Will only be called if tapToFocus = true
    // Returns a CGPoint of the tap location on the preview layer
    print("didFocusAtPoint")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
    // Called when a user initiates a pinch gesture on the preview layer
    // Will only be called if pinchToZoomn = true
    // Returns a CGFloat of the current zoom level
    print("didChangeZoomLevel")
  }
  
  func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
    // Called when user switches between cameras
    // Returns current camera selection
    print("didSwitchCameras")
  }
}
