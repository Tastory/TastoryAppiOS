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


class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate {

  // MARK: - Class Constants
  private struct MapLocationConstants {
    static let defaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let defaultMaxMapSpan = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(0.05),
                                                    longitudeDelta: CLLocationDegrees(0.05))
    static let defaultMinMapSpan = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(0.005),
                                                    longitudeDelta: CLLocationDegrees(0.005))
    
    static let defaultDistanceFilter = 30.0  // meters, for LocationManager

  }
  
  
  // MARK: - Class Variables
  private var locationManager = CLLocationManager()
  private var currentMapSpan: MKCoordinateSpan = MapLocationConstants.defaultMaxMapSpan
  

  // MARK: - IBOutlets
  @IBOutlet weak var mapView: MKMapView?
  @IBOutlet weak var panGestureRecognizer: UIPanGestureRecognizer?
  @IBOutlet weak var pinchGestureRecognizer: UIPinchGestureRecognizer?
  @IBOutlet weak var doubleTapGestureRecognizer: UITapGestureRecognizer?
  @IBOutlet weak var singleTapGestureRecognizer: UITapGestureRecognizer?
  @IBOutlet weak var locationField: UITextField?
  
  
  // MARK: - IBActions
  
  @IBAction func singleTapGestureDetected(_ sender: UITapGestureRecognizer) {
    // Dismiss keyboard if any gestures detected against Map
    locationField?.resignFirstResponder()
  }
  
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
    
    // Restrict to a certain range of zoom when returning map to current location
    // See MKCoordinateSpan+Extensions
    if let mapView = mapView {
      currentMapSpan = min(mapView.region.span, MapLocationConstants.defaultMaxMapSpan)
      currentMapSpan = max(currentMapSpan, MapLocationConstants.defaultMinMapSpan)
    }

    // Start updating location again
    locationManager.startUpdatingLocation()
  }
  
  
  // MARK: - View Controller Life Cycles
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    mapView?.delegate = self
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    doubleTapGestureRecognizer?.delegate = self
    singleTapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    
    // Provide a default Map Region incase Location Update is slow or user denies authorization
    let region = MKCoordinateRegion(center: MapLocationConstants.defaultCLCoordinate2D,
                                    span: MapLocationConstants.defaultMinMapSpan)
    mapView?.setRegion(region, animated: false)
    
    // Setup Location Manager and Start Location Updates
    locationManager.delegate = self
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest //kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = MapLocationConstants.defaultDistanceFilter
    locationManager.activityType = CLActivityType.fitness  // Fitness Type includes Walking
    locationManager.allowsBackgroundLocationUpdates = false
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.disallowDeferredLocationUpdates()
    locationManager.startUpdatingLocation()

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

  
  // MARK: - CLLocationManager Delegates
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    let region = MKCoordinateRegion(center: locations[0].coordinate, span: currentMapSpan)
    mapView?.setRegion(region, animated: true)
  }
  
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error.localizedDescription)  // TODO: Log this error to internal log with a certain verbose level
    
    guard let errorCode = error as? CLError else {
      assertionFailure("Not getting CLError upon a Location Manager Error")
      return
    }
    
    print("DEBUG_ERROR: CLError Code = \(errorCode.code.rawValue)")
    switch errorCode.code {
    case .locationUnknown, .headingFailure:
      // Allow to just continue and hope for a better update later
      break
    case .denied:
      // User denied authorization
      manager.stopUpdatingLocation()
      // TODO: Do we need to do more here?
    default:
      // Allow to just continue and hope for a better update later
      break
    }
  }
  
  /*
  // MARK: - MKMapView Delegates
  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    print("Region Will Change Called")
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    print("Region Did Change Called")
  }
 */
  
  // MARK: - UIGestureRecognizer Delegates
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  
  // MARK: - UITextField Delegates
  
  // TODO: Make dynamic continuous query to provide Geocoding suggestions, and to not use CLGeocoder...
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    
    if let location = textField.text, let region = mapView?.region {
      
      print ("DEBUG_PRINT: CLRegion = \(region.toCLRegion())")
      let geocoder = CLGeocoder()
      geocoder.geocodeAddressString(location, in: region.toCLRegion()) { (placemarks, error) in
        
        if let error = error as? CLError {
          switch error.code {
          case .geocodeFoundNoResult:
            textField.text = "No Results Found"
            textField.textColor = UIColor.red
          default:
            print("DEBUG_ERROR: Geocode Error - \(error)") // TODO: Error Handling, which errors and how to handle?
          }
        }
        
        if let placemarks = placemarks {
          
          print ("DEBUG_PRINT: There are \(placemarks.count) Placemarks")
          
          var textArray = [String]() // TODO: Refactor Code
          
          if let text = placemarks[0].name {
            textArray.append(text)
          }
          
          if let text = placemarks[0].thoroughfare, placemarks[0].name == nil {
            if !textArray.contains(text) { textArray.append(text) }
          }
          
          if let text = placemarks[0].locality {
            if !textArray.contains(text) { textArray.append(text) }
          }
          
          if let text = placemarks[0].administrativeArea {
            if !((text.lowercased() == location.lowercased()) && (text.characters.count == 2)){
              if !textArray.contains(text) { textArray.append(text) }
            }
          }
          
          if let text = placemarks[0].country, !((placemarks[0].name != nil || placemarks[0].thoroughfare != nil) && placemarks[0].locality != nil && placemarks[0].administrativeArea != nil) {
            if !textArray.contains(text) { textArray.append(text) }
          }
          
          textField.text = textArray[0]
          
          var index = 1
          
          while index < textArray.count {
            textField.text = textField.text! + ", " + textArray[index]
            index = index + 1
          }
          
          self.locationManager.stopUpdatingLocation()
          
          if let clRegion = placemarks[0].region as? CLCircularRegion {
            print("DEBUG_PRINT: clRegion used")
            let mkRegion = MKCoordinateRegion(region: clRegion)
            self.mapView?.setRegion(mkRegion, animated: true)
          } else {
            if let coordinate = placemarks[0].location?.coordinate {
              print("DEBUG_PRINT: clRegion not clCircularRegion")
              let region = MKCoordinateRegion(center: coordinate, span: MapLocationConstants.defaultMaxMapSpan)
              self.mapView?.setRegion(region, animated: true)
            } else {
              print("DEBUG_ERROR: Placemark contained no location")
            }
          
          }
        }
      }
    }
    
    textField.resignFirstResponder()
    return true
  }
  
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    
    // Set the text field color back to black once user starts editing. Might have been set to Red for errors.
    textField.textColor = UIColor.black
    return true
  }
}
