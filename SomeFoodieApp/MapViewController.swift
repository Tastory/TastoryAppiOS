//
//  MapViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation


class MapViewController: UIViewController {

  // MARK: - Class Constants
  fileprivate struct Constants {
    static let defaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let defaultMaxDelta: CLLocationDegrees = 0.05
    static let defaultMinDelta: CLLocationDegrees = 0.005
    static let defaultDistanceFilter = 30.0  // meters, for LocationManager
  }
  
  
  // MARK: - Class Variables
  fileprivate var locationManager = CLLocationManager()
  fileprivate var currentMapDelta = Constants.defaultMaxDelta
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var mapView: MKMapView?
  @IBOutlet weak var panGestureRecognizer: UIPanGestureRecognizer?
  @IBOutlet weak var pinchGestureRecognizer: UIPinchGestureRecognizer?
  @IBOutlet weak var doubleTapGestureRecognizer: UITapGestureRecognizer?
  @IBOutlet weak var singleTapGestureRecognizer: UITapGestureRecognizer?
  @IBOutlet weak var locationField: UITextField?
  
  
  // MARK: - IBActions
  @IBAction func unwindToMap(segue: UIStoryboardSegue) {
    // Nothing for now
  }
  
  
  @IBAction func singleTapGestureDetected(_ sender: UITapGestureRecognizer) {
    // Dismiss keyboard if any gestures detected against Map
    locationField?.resignFirstResponder()
  }
  
  
  // Pan, Pinch, Double-Tap gestures all routed here
  @IBAction func mapGestureDetected(_ recognizer: UIGestureRecognizer) {
    
    // Dismiss keyboard if any gestures detected against Map
    locationField?.resignFirstResponder()
    
    // Stop updating location if any gestures detected against Map
    switch recognizer.state {
    case .began, .ended:
      locationManager.stopUpdatingLocation()
    default:
      break
    }
  }
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {
    
    // Clear the text field while at it
    locationField?.text = ""
    
    // Take the lesser of current or default max latitude degrees
    currentMapDelta = min(currentMapDelta, Constants.defaultMaxDelta)
    
    // Take the greater of current or default min latitude degrees
    currentMapDelta = max(currentMapDelta, Constants.defaultMinDelta)
    
    // Start updating location again
    locationManager.startUpdatingLocation()
  }
  
  
  // MARK: - Class Private Functions
  
  // Generic error dialogue box to the user on internal errors
  fileprivate func internalErrorDialog() {
    let alertController = UIAlertController(title: "SomeFoodieApp",
                                            titleComment: "Alert diaglogue title when a Map view internal error occured",
                                            message: "An internal error has occured. Please try again",
                                            messageComment: "Alert dialogue message when a Map view internal error occured",
                                            preferredStyle: .alert)
    alertController.addAlertAction(title: "OK", comment: "Button in alert dialogue box for generic MapView errors", style: .cancel)
    self.present(alertController, animated: true, completion: nil)
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    //mapView?.delegate = self
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    doubleTapGestureRecognizer?.delegate = self
    singleTapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    
    // Provide a default Map Region incase Location Update is slow or user denies authorization
    let region = MKCoordinateRegion(center: Constants.defaultCLCoordinate2D,
                                    span: MKCoordinateSpan(latitudeDelta: Constants.defaultMaxDelta, longitudeDelta: Constants.defaultMaxDelta))
    mapView?.setRegion(region, animated: false)
    
    // Setup Location Manager and Start Location Updates
    locationManager.delegate = self
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest //kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = Constants.defaultDistanceFilter
    locationManager.activityType = CLActivityType.fitness  // Fitness Type includes Walking
    locationManager.allowsBackgroundLocationUpdates = false
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.disallowDeferredLocationUpdates()
    locationManager.startUpdatingLocation()

  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // TODO: Dispose of any resources that can be recreated.
  }
  
  
  /*
  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
  }
  */

}


extension MapViewController: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    let region = MKCoordinateRegion(center: locations[0].coordinate, span: MKCoordinateSpan(latitudeDelta: currentMapDelta, longitudeDelta: currentMapDelta))
    mapView?.setRegion(region, animated: true)
  }
  
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    
    guard let errorCode = error as? CLError else {
      internalErrorDialog()
      DebugPrint.assert("Not getting CLError upon a Location Manager Error")
      return
    }
    
    DebugPrint.error("CLError.code = \(errorCode.code.rawValue)")
    
    switch errorCode.code {

    case .denied:
      // User denied authorization
      manager.stopUpdatingLocation()

      // Permission was denied before. Ask for permission again
      guard let url = URL(string: UIApplicationOpenSettingsURLString) else {
        DebugPrint.assert("UIApplicationOPenSettignsURLString ia an invalid URL String???")
        break
      }
      
      let alertController = UIAlertController(title: "Location Services Disabled",
                                              titleComment: "Alert diaglogue title when user has denied access to location services",
                                              message: "Please go to Settings > Privacy > Location Services and set this App's Location Access permission to 'While Using'",
                                              messageComment: "Alert dialogue message when the user has denied access to location services",
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "Settings",
                                     comment: "Alert diaglogue button to open Settings, hoping user will enable access to Location Services",
                                     style: .default) { action in UIApplication.shared.open(url, options: [:]) }
      
      self.present(alertController, animated: true, completion: nil)

    default:
      DebugPrint.assert("Unrecognized fallthrough, error.localizedDescription = \(error.localizedDescription)")
    }
  }
}


extension MapViewController: UIGestureRecognizerDelegate {
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}


extension MapViewController: UITextFieldDelegate {
  
  // TODO: textFieldShouldReturn, implement Dynamic Filter Querying with another Geocoder
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    
    guard let location = textField.text, let region = mapView?.region else {
      // No text in location field, or no map view all together?
      return true
    }
    
    let clRegion = CLCircularRegion(center: region.center,
                                    radius: region.span.height/1.78/2,
                                    identifier: "currentCLRegion")  // TODO: 16:9 assumption is not good enough
    let geocoder = CLGeocoder()
    
    geocoder.geocodeAddressString(location, in: clRegion) { (placemarks, error) in
      
      if let error = error as? CLError {
        switch error.code {
        case .geocodeFoundNoResult:
          textField.text = "No Results Found"
          textField.textColor = UIColor.red
          return
          
        default:
          DebugPrint.assert("geocodeAddressString Error Handle, CLError Code - \(error)")
        }
      }
      
      guard let placemarks = placemarks else {
        
        DebugPrint.userError("No Placemark found from location entered into text field by User")
        
        // No valid placemarks returned
        textField.text = "No Results Found"
        textField.textColor = UIColor.red
        return
      }
      
      // Create String to be shown back to User in the locationField
      var textArray = [String]()
      
      if let text = placemarks[0].name {
        textArray.append(text)
      }
      
      // Remove 'thoroughfare' if there is already a 'name'
      // eg. Don't need Grouse Mountain at Nancy Green Way. Just Grouse Mountain is enough.
      if let text = placemarks[0].thoroughfare, placemarks[0].name == nil {
        if !textArray.contains(text) { textArray.append(text) }
      }
      
      if let text = placemarks[0].locality {
        if !textArray.contains(text) { textArray.append(text) }
      }
      
      if let text = placemarks[0].administrativeArea {
        
        // If this is a province/state code, remove this. 'name' usually takes care of this.
        if !((text.lowercased() == location.lowercased()) && (text.characters.count == 2)){
          if !textArray.contains(text) { textArray.append(text) }
        }
      }
      
      // Don't show country if there is already a name/thoroughfare, and there is city and state information also
      // Exception is if the name and the city is the same, beacause only 1 of the 2 will be shown
      if let text = placemarks[0].country, !((placemarks[0].name != nil || placemarks[0].thoroughfare != nil) &&
                                             (placemarks[0].name != placemarks[0].locality) &&
                                            placemarks[0].locality != nil && placemarks[0].administrativeArea != nil) {
        if !textArray.contains(text) { textArray.append(text) }
      }
      
      // Place String into locationField formatted with commas
      textField.text = textArray[0]
      var index = 1
      
      while index < textArray.count {
        textField.text = textField.text! + ", " + textArray[index]
        index = index + 1
      }
      
      // Move map to region as indicated by CLPlacemark
      self.locationManager.stopUpdatingLocation()
      
      var region: MKCoordinateRegion?
      
      // The coordinate in palcemarks.region is highly inaccurate. So use the location coordinate when possible.
      if let coordinate = placemarks[0].location?.coordinate, let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemark.locaiton.coordinate if possible
        region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(height: clRegion.radius*2*1.39))  // 1.39 is between square and 16:9 // TODO: 16:9 assumption is not good enough
        
      } else if let coordinate = placemarks[0].location?.coordinate {
        // Determine region via placemark.location.coordinate and default max delta if clRegion is not available
        region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: Constants.defaultMaxDelta, longitudeDelta: Constants.defaultMaxDelta))
        
      } else if let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemarks.region as fall back
        region = MKCoordinateRegion(center: clRegion.center, span: MKCoordinateSpan(height: clRegion.radius*2))
        
      } else {
        DebugPrint.assert("Placemark contained no location")
        
        // There actually isn't a valid location in the placemark...
        textField.text = "No Results Found"
        textField.textColor = UIColor.red
        return
      }
      
      if let region = region {
        self.mapView?.setRegion(region, animated: true)
      }
    }
    
    // Get rid of the keybaord
    textField.resignFirstResponder()
    return true
  }
  
  
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    
    // Set the text field color back to black once user starts editing. Might have been set to Red for errors.
    textField.textColor = UIColor.black
    return true
  }
  
//  let userInfo = notification.userInfo!
//  let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue().height
//  let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! Double
//  let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! UInt
//  let moveUp = (notification.name == UIKeyboardWillShowNotification)
}
